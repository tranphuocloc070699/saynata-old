package com.englishtranslation.backend.claude;

import com.fasterxml.jackson.annotation.JsonPropertyDescription;
import java.util.List;

/**
 * What Claude returns for the language lines of word senses in ONE language: per item the line and the headword
 * translated for that sense, in the order of the items. The fast first answer of the language row; the other
 * languages follow in the background with {@link WordLinesAnswer}.
 */
public record WordLineAnswer(
        @JsonPropertyDescription("One item for each input item, in the same order. Exactly as many items as input items.") List<Item> items) {

    /** The line and the headword of one item in the target language. */
    public record Item(
            @JsonPropertyDescription("The line in the target language") String line,
            @JsonPropertyDescription("The headword in the target language for this meaning, or empty") String headword) {
    }
}
