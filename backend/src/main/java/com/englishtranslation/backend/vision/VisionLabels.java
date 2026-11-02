package com.englishtranslation.backend.vision;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

/**
 * Which labels GET /api/words/{label} may describe although they are not on the English word list (TASK-121.1).
 * The backend decides, not the client (same rule as the sentence wordMatch, TASK-114.5), so nobody can make the
 * LLM describe any text. Two sources:
 * <ol>
 * <li>the 30 Vietnamese dishes in resources/words/dishes.txt (accented), also found without accents ("pho" gives
 * "phở");</li>
 * <li>every label the vision endpoint returned for the current vision prompt version.</li>
 * </ol>
 */
@Component
public class VisionLabels {

    private static final String DISHES_FILE = "words/dishes.txt";

    /** Accent-free dish to the accented dish. The accented dish maps to itself. */
    private final Map<String, String> dishes = new HashMap<>();
    private final VisionIdentifyRepository identified;
    private final String promptVersion;

    public VisionLabels(VisionIdentifyRepository identified,
            @Value("${app.claude.vision-prompt-version:v1}") String promptVersion) {
        this.identified = identified;
        this.promptVersion = promptVersion;
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new ClassPathResource(DISHES_FILE).getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String dish = nfc(line.strip().toLowerCase(Locale.ROOT));
                if (!dish.isEmpty()) {
                    dishes.put(dish, dish);
                    dishes.put(withoutAccents(dish), dish);
                }
            }
        } catch (IOException e) {
            throw new UncheckedIOException("Could not read " + DISHES_FILE, e);
        }
    }

    /** The accented dish for a normalized text ("pho" and "phở" both give "phở"), or empty when it is not a dish. */
    public Optional<String> dish(String normalized) {
        return Optional.ofNullable(dishes.get(nfc(normalized)));
    }

    /** True when the text is a dish or a label the vision endpoint returned (current prompt version). */
    public boolean isAnswerable(String normalized) {
        return dish(normalized).isPresent() || identified.existsByLabelAndPromptVersion(nfc(normalized), promptVersion);
    }

    static String nfc(String text) {
        return Normalizer.normalize(text, Normalizer.Form.NFC);
    }

    static String withoutAccents(String text) {
        return Normalizer.normalize(text.replace('đ', 'd'), Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
    }
}
