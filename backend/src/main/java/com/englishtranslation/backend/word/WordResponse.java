package com.englishtranslation.backend.word;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * The reply of GET /api/words/{word}. ipa is filled at request time from IpaDictionary, not saved
 * with the cached entry. It is null when the word is not on the IPA list.
 * Each sense of the entry may have an imageUrl (see WordEntryView).
 * matchedForm (TASK-118) is set when the text was a form of the word ("ran" for "run"): then {@code word} is the
 * lemma. It is left out of the JSON otherwise, so replies for a base word look as before.
 */
public record WordResponse(String word, WordEntryView entry, boolean cached, String ipa,
        @JsonInclude(JsonInclude.Include.NON_NULL) MatchedForm matchedForm) {

    public WordResponse(String word, WordEntryView entry, boolean cached, String ipa) {
        this(word, entry, cached, ipa, null);
    }

    /** The form the user typed, lower case ("ran"), and what kind of form it is ("past tense"). */
    public record MatchedForm(String text, String type) {
    }

    public WordResponse withMatchedForm(String form, String type) {
        return new WordResponse(word, entry, cached, ipa, new MatchedForm(form, type));
    }
}
