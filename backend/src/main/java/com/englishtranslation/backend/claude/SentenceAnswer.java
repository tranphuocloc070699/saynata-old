package com.englishtranslation.backend.claude;

import com.englishtranslation.backend.translation.Explanation;
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyDescription;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * What Claude returns for a text (prompt v12, TASK-114.1): the language of the text, the natural English version when
 * the text is not English, a word match for one non-English word, then a short summary in simple English (one line, or
 * a gist line and up to 3 "- " bullets with **bold** key words) and a fixed version of the English text when it has a
 * real mistake ("" when it is natural, TASK-110) with a one-line reason. The language line is not asked here
 * (TASK-106.6): it comes from line_translation. {@code sourceLang} "none" (code, gibberish) is only for the backend:
 * ClaudeService turns it into a {@link NotEnglishException}, so the app and the DB never see it. There is no words
 * list any more; the app explains words from the dictionary.
 *
 * Answers before v12 had {@code "isEnglish": true/false} instead of {@code sourceLang}; they are still read
 * (true is "en", false is "none").
 */
@JsonPropertyOrder({ "sourceLang", "english", "wordMatch", "summary", "better", "betterWhy" })
public record SentenceAnswer(
        @JsonPropertyDescription("ISO 639-1 code of the language of the text, lowercase: \"en\" for English, \"vi\" for Vietnamese. \"none\" for program code or random letters.") String sourceLang,
        @JsonPropertyDescription("The natural English a native speaker would say for the text, when the text is not English. \"\" when the text is English or sourceLang is \"none\".") String english,
        @JsonPropertyDescription("Only when the text is ONE non-English word, phrasal verb or idiom that has a good single English match: that English headword, phrasal verb or idiom in lower case. \"\" for everything else.") String wordMatch,
        @JsonPropertyDescription("What the English text says in simple B1 English. Short text: one sentence. Longer text: a gist line, then up to 3 lines starting with \"- \", at most half as long; **bold** for 1-3 key terms. The content itself, never a description of it.") String summary,
        @JsonPropertyDescription("The English text with only its real mistakes fixed (grammar, a wrong word, a phrase a native speaker would not say). \"\" when the text is correct, long, not English, or reads like a book, news or a website.") String better,
        @JsonPropertyDescription("\"\" when better is \"\". Else one short line in simple B1 English that says why.") String betterWhy) {

    /** One word or a phrase of up to 6 words: the same rule as the word path in WordController. */
    private static final Pattern WORD_PATH = Pattern.compile("(?=.{1,64}$)[\\p{L}'-]+( [\\p{L}'-]+){0,5}");

    /** Reads new answers and old ones (with {@code isEnglish}). A missing sourceLang and isEnglish means English. */
    @JsonCreator
    public static SentenceAnswer fromJson(@JsonProperty("sourceLang") String sourceLang,
            @JsonProperty("english") String english, @JsonProperty("wordMatch") String wordMatch,
            @JsonProperty("summary") String summary, @JsonProperty("better") String better,
            @JsonProperty("betterWhy") String betterWhy, @JsonProperty("isEnglish") Boolean isEnglish) {
        String lang = sourceLang;
        if (lang == null && isEnglish != null) {
            lang = isEnglish ? "en" : "none";
        }
        return new SentenceAnswer(lang, english, wordMatch, summary, better, betterWhy);
    }

    /** An answer for English text without a fix, as v10 wrote it. Kept for tests and callers that do not care. */
    public SentenceAnswer(boolean isEnglish, String summary) {
        this(isEnglish, summary, "", "");
    }

    /** An answer for English text (or "none") with a fix. */
    public SentenceAnswer(boolean isEnglish, String summary, String better, String betterWhy) {
        this(isEnglish ? "en" : "none", "", "", summary, better, betterWhy);
    }

    /** The ISO code in lowercase without a region ("zh-CN" is "zh"). "en" when the model sent none (old answers). */
    public String languageCode() {
        if (sourceLang == null) {
            return "en";
        }
        String lang = sourceLang.strip().toLowerCase(Locale.ROOT);
        int dash = lang.indexOf('-');
        return dash > 0 ? lang.substring(0, dash) : lang;
    }

    /** True for code and gibberish (and for an answer without a usable language code). */
    public boolean hasNoLanguage() {
        return !languageCode().matches("[a-z]{2,3}");
    }

    public boolean englishText() {
        return "en".equals(languageCode());
    }

    /**
     * The explanation. The translation is empty here; TranslationService fills it. Call this only for an answer that is
     * not "none". For non-English text {@code english}, {@code sourceLang} and {@code wordMatch} are set; for English
     * text they are null, so nothing changes in the JSON. Old app versions still read {@code meaning} and
     * {@code words}, so the summary is the meaning and the words list is always empty. The summary is cleaned to the
     * Markdown subset the clients render ({@link SummaryFormat}). A blank fix becomes null; TranslationService still
     * checks a fix against the text ({@code BetterCheck}). Non-English text with no English version cannot be
     * explained: that is a {@link NotEnglishException}.
     */
    public Explanation toExplanation() {
        String meaning = SummaryFormat.clean(summary);
        if (englishText()) {
            String fix = blankToNull(better);
            return new Explanation(null, null, null, meaning, List.of(), fix, fix == null ? null : blankToNull(betterWhy),
                    "");
        }
        String englishVersion = blankToNull(english);
        if (englishVersion == null) {
            throw new NotEnglishException();
        }
        return new Explanation(englishVersion, languageCode(), validWordMatch(wordMatch), meaning, List.of(), null, null,
                "");
    }

    /** The word match in lower case when it is a valid word path (one word or a phrase of up to 6), else null. */
    static String validWordMatch(String value) {
        String match = blankToNull(value);
        if (match == null) {
            return null;
        }
        match = match.toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");
        return WORD_PATH.matcher(match).matches() ? match : null;
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.strip();
    }
}
