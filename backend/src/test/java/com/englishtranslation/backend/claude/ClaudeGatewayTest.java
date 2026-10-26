package com.englishtranslation.backend.claude;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import com.anthropic.client.AnthropicClient;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The main model endpoint (DEEPSEEK_BASE_URL + DEEPSEEK_API_KEY): the client calls its URL with the key, and every
 * call switches thinking off (TASK-117).
 */
class ClaudeGatewayTest {

    private static final String REPLY = "{\"id\":\"msg_1\",\"type\":\"message\",\"role\":\"assistant\","
            + "\"model\":\"claude-haiku-4-5\",\"content\":[{\"type\":\"text\",\"text\":\"{}\"}],"
            + "\"stop_reason\":\"end_turn\",\"stop_sequence\":null,\"usage\":{\"input_tokens\":5,\"output_tokens\":1}}";

    private HttpServer server;
    private final AtomicReference<String> path = new AtomicReference<>();
    private final AtomicReference<String> authorization = new AtomicReference<>();
    private final AtomicReference<String> apiKeyHeader = new AtomicReference<>();
    private final AtomicReference<String> body = new AtomicReference<>();

    @BeforeEach
    void startGateway() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            path.set(exchange.getRequestURI().getPath());
            authorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
            apiKeyHeader.set(exchange.getRequestHeaders().getFirst("x-api-key"));
            body.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] answer = REPLY.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, answer.length);
            exchange.getResponseBody().write(answer);
            exchange.close();
        });
        server.start();
    }

    @AfterEach
    void stopGateway() {
        server.stop(0);
    }

    private LlmProperties gateway(String apiKey) {
        String url = "http://127.0.0.1:" + server.getAddress().getPort() + "/api";
        return new LlmProperties(apiKey, "deepseek-flash", "v1", "v1", url, null, null, null, null);
    }

    @Test
    void callsTheEndpointUrlWithTheKeyAndSwitchesThinkingOff() {
        LlmProperties properties = gateway("sk-deepseek");
        AnthropicClient client = new LlmConfig().anthropicClient(properties);

        new ClaudeService(client, properties, mock(ClaudeUsageService.class)).warmUp();

        assertThat(path.get()).isEqualTo("/api/v1/messages");
        assertThat(apiKeyHeader.get()).isEqualTo("sk-deepseek");
        assertThat(body.get()).contains("\"model\":\"deepseek-flash\"").contains("\"thinking\":{\"type\":\"disabled\"}");
    }

    @Test
    void startUpFailsWithAClearMessageWhenTheDeepSeekKeyIsEmpty() {
        assertThatThrownBy(() -> new LlmConfig().anthropicClient(gateway(" ")))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("DEEPSEEK_API_KEY");
    }
}
