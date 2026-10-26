package com.englishtranslation.backend.claude;

import java.util.Optional;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.ConstructorBinding;

/**
 * The language-model settings (TASK-117). The main model is DeepSeek, called through its Anthropic-compatible
 * endpoint ({@code apiKey}, {@code model}, {@code baseUrl}); Gemini is the fallback ({@code fallbackApiKey},
 * {@code fallbackModel}, {@code fallbackBaseUrl}, an OpenAI-compatible endpoint). The prefix stays {@code app.claude}
 * because prompt versions, prices and limits already live there. {@code temperature} is sent with the sentence calls
 * only (TASK-89.3), empty = not sent.
 */
@ConfigurationProperties("app.claude")
public record LlmProperties(String apiKey, String model, String sentencePromptVersion, String wordPromptVersion,
        String baseUrl, String temperature, String fallbackApiKey, String fallbackModel, String fallbackBaseUrl) {

    @ConstructorBinding
    public LlmProperties {
    }

    /** The short shape, for tests: the main model with no base URL (the SDK's own default), no fallback. */
    public LlmProperties(String apiKey, String model, String sentencePromptVersion, String wordPromptVersion) {
        this(apiKey, model, sentencePromptVersion, wordPromptVersion, null, null, null, null, null);
    }

    /**
     * True when calls go to a custom base URL (always, in production): then the JSON Schema is put in the prompt
     * and the answer is parsed from the text, because DeepSeek ignores the strict JSON setting.
     */
    public boolean jsonInPrompt() {
        return baseUrl != null && !baseUrl.isBlank();
    }

    /** True when there is a main-model key to call with. */
    public boolean hasCredentials() {
        return apiKey != null && !apiKey.isBlank();
    }

    /** True when a Gemini key is set, so a failed main call can be answered by the fallback. */
    public boolean hasFallback() {
        return fallbackApiKey != null && !fallbackApiKey.isBlank();
    }

    /** The temperature for sentence calls, or empty when {@code temperature} is blank. */
    public Optional<Double> sentenceTemperature() {
        if (temperature == null || temperature.isBlank()) {
            return Optional.empty();
        }
        return Optional.of(Double.parseDouble(temperature.trim()));
    }
}
