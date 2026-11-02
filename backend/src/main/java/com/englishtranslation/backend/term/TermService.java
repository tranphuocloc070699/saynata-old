package com.englishtranslation.backend.term;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * TASK-119.1: the terms written as this text ("nuxtjs" -> Nuxt), matched by {@link TermKeys#key}. At most
 * {@link #MAX_TERMS}, most popular first, so a shared alias ("ts") shows a few cards instead of a guess.
 */
@Service
public class TermService {

    public static final int MAX_TERMS = 3;

    private final JdbcTemplate jdbc;

    public TermService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Term> find(String text) {
        String key = TermKeys.key(text);
        if (key.isEmpty()) {
            return List.of();
        }
        return jdbc.query(
                "select t.name, t.field, t.simple_definition, t.official_url, t.wikipedia_url from term t"
                        + " where t.id in (select a.term_id from term_alias a where a.alias_key = ?)"
                        + " order by t.popularity desc, t.id limit " + MAX_TERMS,
                (row, i) -> new Term(row.getString(1), row.getString(2), row.getString(3), row.getString(4),
                        row.getString(5)),
                key);
    }
}
