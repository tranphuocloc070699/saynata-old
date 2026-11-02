package com.englishtranslation.backend.term;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * TASK-119.1: the key a term alias is stored and searched by. Lower case, without dots, dashes, underscores,
 * apostrophes and spaces, so "Nuxt.js", "NuxtJS", "nuxt js" and "nuxtjs" are the same key. The pipeline has the
 * same rule (exports/terms/build_terms.py, alias_key); keep them in step.
 */
public final class TermKeys {

    private static final Pattern DROPPED = Pattern.compile("[\\s._'’-]+");

    private TermKeys() {
    }

    public static String key(String text) {
        if (text == null) {
            return "";
        }
        return DROPPED.matcher(text.toLowerCase(Locale.ROOT)).replaceAll("");
    }
}
