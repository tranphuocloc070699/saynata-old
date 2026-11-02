package com.englishtranslation.backend.word;

import java.util.List;
import java.util.stream.Stream;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * TASK-118: which words a form belongs to ("ran" -> run, "contaminated" -> contaminate, "gave up" -> give up).
 * Forms of bundled words come from dictionary_form (the pipeline export, TASK-35), forms of backend words from
 * word_form (exports/word-forms, V38). Bundled matches come first, so a form of a bundled word answers like iOS.
 */
@Component
public class WordForms {

    /** One word a form belongs to. {@code bundled} says which table the lemma's entry is in. */
    public record Match(String lemma, String type, boolean bundled) {
    }

    private static final String UNKNOWN_TYPE = "form";

    private final JdbcTemplate jdbc;

    public WordForms(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Every lemma of this form (lower case), bundled first. Empty when the text is not a known form. */
    public List<Match> find(String form) {
        List<Match> bundled = jdbc.query(
                "select w.lemma, f.form_type from dictionary_form f join dictionary_word w on w.id = f.word_id"
                        + " where f.form = ? and w.lemma <> ? order by w.word_rank, w.id",
                (row, i) -> new Match(row.getString(1), typeOrForm(row.getString(2)), true), form, form);
        List<Match> backend = jdbc.query(
                "select lemma, form_type from word_form where form = ? and lemma <> ? order by id",
                (row, i) -> new Match(row.getString(1), typeOrForm(row.getString(2)), false), form, form);
        return Stream.concat(bundled.stream(), backend.stream()).toList();
    }

    private static String typeOrForm(String type) {
        return type == null || type.isBlank() ? UNKNOWN_TYPE : type;
    }
}
