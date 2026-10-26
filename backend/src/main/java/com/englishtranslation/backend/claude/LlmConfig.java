package com.englishtranslation.backend.claude;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import java.time.Duration;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties({ LlmProperties.class, UsageProperties.class })
public class LlmConfig {

    static final String MISSING_KEY = "Set DEEPSEEK_API_KEY: the main language model (DeepSeek) cannot be called without it."
            + " See backend/.env.example, section 1.";

    /** The main model: DeepSeek through its Anthropic-compatible endpoint. Start-up fails without a key. */
    @Bean
    public AnthropicClient anthropicClient(LlmProperties properties) {
        if (!properties.hasCredentials()) {
            throw new IllegalStateException(MISSING_KEY);
        }
        AnthropicOkHttpClient.Builder builder = AnthropicOkHttpClient.builder().apiKey(properties.apiKey());
        if (properties.baseUrl() != null && !properties.baseUrl().isBlank()) {
            builder.baseUrl(properties.baseUrl());
        }
        return builder
                // Keep a few HTTPS connections open between calls, so a new sentence does not pay for a new
                // TCP and TLS handshake (TASK-75). The SDK default is 5 connections for 5 minutes.
                .maxIdleConnections(5)
                .keepAliveDuration(Duration.ofMinutes(10))
                .build();
    }

    /** The fallback model. Without a Gemini key it is a client that is not configured: the router skips it. */
    @Bean
    public GeminiClient geminiClient(LlmProperties properties) {
        return new GeminiClient(properties.fallbackBaseUrl(), properties.fallbackApiKey(), properties.fallbackModel());
    }
}
