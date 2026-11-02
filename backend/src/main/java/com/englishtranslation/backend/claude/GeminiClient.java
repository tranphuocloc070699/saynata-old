package com.englishtranslation.backend.claude;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

/**
 * The fallback model (TASK-117): Gemini through its OpenAI-compatible endpoint
 * (https://ai.google.dev/gemini-api/docs/openai). Same prompts as the main model, JSON in the prompt. Plain HTTP,
 * no SDK. Not configured (no key) = {@link #configured()} is false and the router never calls it.
 */
public class GeminiClient {

    /** What the model said and what it cost in tokens. */
    public record Reply(String text, long inputTokens, long outputTokens) {
    }

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Duration TIMEOUT = Duration.ofSeconds(60);

    private final String baseUrl;
    private final String apiKey;
    private final String model;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

    public GeminiClient(String baseUrl, String apiKey, String model) {
        this.baseUrl = baseUrl == null ? "" : baseUrl.replaceAll("/+$", "");
        this.apiKey = apiKey == null ? "" : apiKey;
        this.model = model;
    }

    public boolean configured() {
        return !apiKey.isBlank() && !baseUrl.isBlank();
    }

    public String model() {
        return model;
    }

    /** One answer in one piece. */
    public Reply complete(String system, String user, long maxTokens, Double temperature) {
        try {
            HttpResponse<String> response = http.send(request(system, user, maxTokens, temperature, false),
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            requireOk(response.statusCode(), response.body());
            JsonNode root = JSON.readTree(response.body());
            String text = root.path("choices").path(0).path("message").path("content").asText("");
            return new Reply(text, root.path("usage").path("prompt_tokens").asLong(0),
                    root.path("usage").path("completion_tokens").asLong(0));
        } catch (IOException e) {
            throw new IllegalStateException("Gemini call failed: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Gemini call was interrupted.", e);
        }
    }

    /**
     * One answer about one photo (TASK-121.1). The image goes inline as a base64 data URI in an {@code image_url} part,
     * which the OpenAI-compatible endpoint turns into Gemini's {@code inline_data}. The photo is only in this request.
     */
    public Reply describeImage(String system, String text, byte[] image, String mimeType, long maxTokens,
            Double temperature) {
        try {
            Map<String, Object> body = new java.util.LinkedHashMap<>();
            body.put("model", model);
            body.put("max_tokens", maxTokens);
            String dataUri = "data:" + mimeType + ";base64," + java.util.Base64.getEncoder().encodeToString(image);
            body.put("messages", List.of(Map.of("role", "system", "content", system),
                    Map.of("role", "user", "content", List.of(
                            Map.of("type", "text", "text", text),
                            Map.of("type", "image_url", "image_url", Map.of("url", dataUri))))));
            if (temperature != null) {
                body.put("temperature", temperature);
            }
            HttpRequest request = HttpRequest.newBuilder(URI.create(baseUrl + "/chat/completions"))
                    .timeout(TIMEOUT)
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(JSON.writeValueAsString(body)))
                    .build();
            HttpResponse<String> response = http.send(request,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            requireOk(response.statusCode(), response.body());
            JsonNode root = JSON.readTree(response.body());
            return new Reply(root.path("choices").path(0).path("message").path("content").asText(""),
                    root.path("usage").path("prompt_tokens").asLong(0),
                    root.path("usage").path("completion_tokens").asLong(0));
        } catch (IOException e) {
            throw new IllegalStateException("Gemini call failed: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Gemini call was interrupted.", e);
        }
    }

    /** The answer as server-sent events: every piece of text goes to {@code onText} as it arrives. */
    public Reply stream(String system, String user, long maxTokens, Double temperature, Consumer<String> onText) {
        try {
            HttpResponse<java.io.InputStream> response = http.send(request(system, user, maxTokens, temperature, true),
                    HttpResponse.BodyHandlers.ofInputStream());
            StringBuilder all = new StringBuilder();
            long input = 0;
            long output = 0;
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(response.body(), StandardCharsets.UTF_8))) {
                if (response.statusCode() / 100 != 2) {
                    requireOk(response.statusCode(), reader.lines().reduce("", String::concat));
                }
                String line;
                while ((line = reader.readLine()) != null) {
                    if (!line.startsWith("data:")) {
                        continue;
                    }
                    String data = line.substring(5).strip();
                    if (data.equals("[DONE]")) {
                        break;
                    }
                    JsonNode event = JSON.readTree(data);
                    String piece = event.path("choices").path(0).path("delta").path("content").asText("");
                    if (!piece.isEmpty()) {
                        all.append(piece);
                        onText.accept(piece);
                    }
                    if (event.path("usage").has("prompt_tokens")) {
                        input = event.path("usage").path("prompt_tokens").asLong(0);
                        output = event.path("usage").path("completion_tokens").asLong(0);
                    }
                }
            }
            return new Reply(all.toString(), input, output);
        } catch (IOException e) {
            throw new IllegalStateException("Gemini call failed: " + e.getMessage(), e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Gemini call was interrupted.", e);
        }
    }

    private HttpRequest request(String system, String user, long maxTokens, Double temperature, boolean stream)
            throws IOException {
        Map<String, Object> body = new java.util.LinkedHashMap<>();
        body.put("model", model);
        body.put("max_tokens", maxTokens);
        body.put("messages", List.of(Map.of("role", "system", "content", system),
                Map.of("role", "user", "content", user)));
        if (temperature != null) {
            body.put("temperature", temperature);
        }
        if (stream) {
            body.put("stream", true);
            body.put("stream_options", Map.of("include_usage", true));
        }
        return HttpRequest.newBuilder(URI.create(baseUrl + "/chat/completions"))
                .timeout(TIMEOUT)
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(JSON.writeValueAsString(body)))
                .build();
    }

    private static void requireOk(int status, String body) {
        if (status / 100 != 2) {
            String shortBody = body.length() > 300 ? body.substring(0, 300) : body;
            throw new IllegalStateException("Gemini answered HTTP " + status + ": " + shortBody);
        }
    }
}
