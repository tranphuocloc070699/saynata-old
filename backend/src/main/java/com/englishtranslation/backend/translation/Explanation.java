package com.englishtranslation.backend.translation;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;
import java.util.List;

/**
 * What the app shows for one sentence. Same JSON shape as `Explanation` in the iOS app.
 * Explain first, translate last: meaning and words are in simple English (B1-B2) and come first;
 * translation is a small helper line in the requested target language and comes last.
 * {@code better} is the text with its real mistakes fixed and {@code betterWhy} says why in one line (TASK-110);
 * both are null when the text is already natural, or for answers saved before prompt v10.
 * For text that is not English (TASK-114.1) three fields come first: {@code english} is the natural English version,
 * {@code sourceLang} the ISO code of the typed language ("vi") and {@code wordMatch} the English headword when the
 * text is one word, phrasal verb or idiom with a good match ("buồn" gives "sad"). For English text all three are null
 * and left out of the JSON, so old apps and old saved answers are not affected. Then {@code meaning} and the rest
 * describe the English version.
 */
@JsonPropertyOrder({ "english", "sourceLang", "wordMatch", "meaning", "words", "better", "betterWhy", "translation" })
public record Explanation(
        @JsonInclude(JsonInclude.Include.NON_NULL) String english,
        @JsonInclude(JsonInclude.Include.NON_NULL) String sourceLang,
        @JsonInclude(JsonInclude.Include.NON_NULL) String wordMatch,
        String meaning, List<Word> words, String better, String betterWhy, String translation) {

    /** An explanation of English text with a fix. */
    public Explanation(String meaning, List<Word> words, String better, String betterWhy, String translation) {
        this(null, null, null, meaning, words, better, betterWhy, translation);
    }

    /** An explanation without a fix. */
    public Explanation(String meaning, List<Word> words, String translation) {
        this(meaning, words, null, null, translation);
    }

    /** The same explanation without its fix. */
    public Explanation withoutBetter() {
        return new Explanation(english, sourceLang, wordMatch, meaning, words, null, null, translation);
    }

    /** The same explanation with another language line. */
    public Explanation withTranslation(String line) {
        return new Explanation(english, sourceLang, wordMatch, meaning, words, better, betterWhy, line);
    }

    /** One difficult word or phrase, written as it appears in the sentence. */
    public record Word(String word, String partOfSpeech, String meaning) {
    }
}
