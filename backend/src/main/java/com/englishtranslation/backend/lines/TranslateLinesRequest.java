package com.englishtranslation.backend.lines;

import com.englishtranslation.backend.translation.TargetLanguage;
import java.util.List;

/**
 * The body of POST /api/translate-lines. An unknown targetLang code fails JSON parsing (400). The rest is checked
 * in {@link LineTranslationService}, so the answer says what is wrong.
 * {@code headwords} (TASK-106.8, optional): for word senses, the English word of each text, in the same order;
 * a null entry asks no headword. Sentences leave it out.
 */
public record TranslateLinesRequest(TargetLanguage targetLang, List<String> texts, List<String> headwords) {

    public TranslateLinesRequest(TargetLanguage targetLang, List<String> texts) {
        this(targetLang, texts, null);
    }
}
