package com.englishtranslation.backend.word;

import com.englishtranslation.backend.term.Term;
import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

/**
 * The reply of GET /api/words/{word}. ipa is filled at request time from IpaDictionary, not saved
 * with the cached entry. It is null when the word is not on the IPA list.
 * Each sense of the entry may have an imageUrl (see WordEntryView).
 * matchedForm (TASK-118) is set when the text was a form of the word ("ran" for "run"): then {@code word} is the
 * lemma. It is left out of the JSON otherwise, so replies for a base word look as before.
 * terms (TASK-119.1) are named things written like the text ("swift": Swift the language), added at request time
 * below the English senses, never in place of them. Left out of the JSON when there are none.
 */
public record WordResponse(String word, WordEntryView entry, boolean cached, String ipa,
        @JsonInclude(JsonInclude.Include.NON_NULL) MatchedForm matchedForm,
        @JsonInclude(JsonInclude.Include.NON_EMPTY) List<Term> terms) {

    public WordResponse {
        terms = terms == null ? List.of() : List.copyOf(terms);
    }

    public WordResponse(String word, WordEntryView entry, boolean cached, String ipa) {
        this(word, entry, cached, ipa, null, List.of());
    }

    /** The form the user typed, lower case ("ran"), and what kind of form it is ("past tense"). */
    public record MatchedForm(String text, String type) {
    }

    public WordResponse withMatchedForm(String form, String type) {
        return new WordResponse(word, entry, cached, ipa, new MatchedForm(form, type), terms);
    }

    public WordResponse withTerms(List<Term> newTerms) {
        return new WordResponse(word, entry, cached, ipa, matchedForm, newTerms);
    }
}
