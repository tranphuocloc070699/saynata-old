package com.englishtranslation.backend.claude;

import com.englishtranslation.backend.translation.TargetLanguage;
import com.fasterxml.jackson.annotation.JsonPropertyDescription;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/** What Claude returns for the language lines of all languages (TASK-106.7): one item per text, in the order of the texts. */
public record AllLinesAnswer(
        @JsonPropertyDescription("One item for each text, in the same order as the texts. Exactly as many items as texts.") List<Item> items) {

    /** The lines of one text, one field per language code. */
    public record Item(
            @JsonPropertyDescription("Vietnamese line") String vi,
            @JsonPropertyDescription("Japanese line") String ja,
            @JsonPropertyDescription("Korean line") String ko,
            @JsonPropertyDescription("Simplified Chinese line") String zh,
            @JsonPropertyDescription("French line") String fr,
            @JsonPropertyDescription("Spanish line") String es,
            @JsonPropertyDescription("German line") String de) {

        /** Language -> line. A missing or blank line is left out. */
        public Map<TargetLanguage, String> byLanguage() {
            return map(vi, ja, ko, zh, fr, es, de);
        }

        /** Language -> value for the 7 languages in this order. A missing or blank value is left out. */
        static Map<TargetLanguage, String> map(String vi, String ja, String ko, String zh, String fr, String es,
                String de) {
            Map<TargetLanguage, String> map = new EnumMap<>(TargetLanguage.class);
            put(map, TargetLanguage.VI, vi);
            put(map, TargetLanguage.JA, ja);
            put(map, TargetLanguage.KO, ko);
            put(map, TargetLanguage.ZH, zh);
            put(map, TargetLanguage.FR, fr);
            put(map, TargetLanguage.ES, es);
            put(map, TargetLanguage.DE, de);
            return map;
        }

        private static void put(Map<TargetLanguage, String> map, TargetLanguage lang, String line) {
            if (line != null && !line.isBlank()) {
                map.put(lang, line.strip());
            }
        }
    }
}
