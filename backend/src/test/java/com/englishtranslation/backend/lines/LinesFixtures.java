package com.englishtranslation.backend.lines;

import com.englishtranslation.backend.translation.TargetLanguage;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/** Fake answers of ClaudeService.translateLinesAllLanguages for tests (TASK-106.7). */
public final class LinesFixtures {

    private LinesFixtures() {
    }

    /** One item per line; each item has this same line in all 7 languages. */
    public static List<Map<TargetLanguage, String>> every(String... lines) {
        List<Map<TargetLanguage, String>> items = new ArrayList<>();
        for (String line : lines) {
            items.add(item(line));
        }
        return items;
    }

    /** One item with "<code>:<line>" in each of the 7 languages, e.g. "ko:hello". */
    public static Map<TargetLanguage, String> item(String line) {
        Map<TargetLanguage, String> map = new EnumMap<>(TargetLanguage.class);
        for (TargetLanguage lang : TargetLanguage.values()) {
            if (lang != TargetLanguage.EN) {
                map.put(lang, line);
            }
        }
        return map;
    }
}
