package com.englishtranslation.backend.claude;

import com.englishtranslation.backend.translation.TargetLanguage;
import com.fasterxml.jackson.annotation.JsonPropertyDescription;
import java.util.List;
import java.util.Map;

/**
 * What Claude returns for the language lines of word senses in all languages (TASK-106.8): per item the line and
 * the headword translated for that sense, in the order of the items.
 */
public record WordLinesAnswer(
        @JsonPropertyDescription("One item for each input item, in the same order. Exactly as many items as input items.") List<Item> items) {

    /** The line and the headword of one item, two fields per language code. */
    public record Item(
            @JsonPropertyDescription("Vietnamese line") String vi,
            @JsonPropertyDescription("The headword in Vietnamese for this meaning, or empty") String viHeadword,
            @JsonPropertyDescription("Japanese line") String ja,
            @JsonPropertyDescription("The headword in Japanese for this meaning, or empty") String jaHeadword,
            @JsonPropertyDescription("Korean line") String ko,
            @JsonPropertyDescription("The headword in Korean for this meaning, or empty") String koHeadword,
            @JsonPropertyDescription("Simplified Chinese line") String zh,
            @JsonPropertyDescription("The headword in Simplified Chinese for this meaning, or empty") String zhHeadword,
            @JsonPropertyDescription("French line") String fr,
            @JsonPropertyDescription("The headword in French for this meaning, or empty") String frHeadword,
            @JsonPropertyDescription("Spanish line") String es,
            @JsonPropertyDescription("The headword in Spanish for this meaning, or empty") String esHeadword,
            @JsonPropertyDescription("German line") String de,
            @JsonPropertyDescription("The headword in German for this meaning, or empty") String deHeadword) {

        public Lines toLines() {
            return new Lines(
                    AllLinesAnswer.Item.map(vi, ja, ko, zh, fr, es, de),
                    AllLinesAnswer.Item.map(viHeadword, jaHeadword, koHeadword, zhHeadword, frHeadword, esHeadword,
                            deHeadword));
        }
    }

    /** Language -> line and language -> headword of one item. A missing or blank value is left out. */
    public record Lines(Map<TargetLanguage, String> lines, Map<TargetLanguage, String> headwords) {
    }
}
