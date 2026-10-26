package com.englishtranslation.backend.claude;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.englishtranslation.backend.translation.Explanation;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * DeepSeek is the main model and Gemini the fallback (TASK-117). Two fake servers on localhost: the real SDK talks
 * to the first, the real Gemini client to the second.
 */
class LlmFallbackTest {

    private static final String SENTENCE_JSON = "{\"sourceLang\":\"en\",\"summary\":\"I stopped trying after a week.\"}";

    private HttpServer main;
    private HttpServer gemini;
    private final AtomicInteger mainCalls = new AtomicInteger();
    private final AtomicInteger geminiCalls = new AtomicInteger();
    private final AtomicReference<String> geminiBody = new AtomicReference<>();
    /** What the fake DeepSeek does: a status and a body; an SSE body when it starts with "event:". */
    private int mainStatus = 500;
    private String mainBody = "{\"type\":\"error\",\"error\":{\"type\":\"api_error\",\"message\":\"down\"}}";
    private String geminiReply;
    private final ClaudeUsageService usage = mock(ClaudeUsageService.class);

    @BeforeEach
    void start() throws IOException {
        main = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        main.createContext("/", exchange -> {
            mainCalls.incrementAndGet();
            exchange.getRequestBody().readAllBytes();
            byte[] answer = mainBody.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type",
                    mainBody.startsWith("event:") ? "text/event-stream" : "application/json");
            exchange.sendResponseHeaders(mainStatus, answer.length);
            exchange.getResponseBody().write(answer);
            exchange.close();
        });
        main.start();
        gemini = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        gemini.createContext("/", exchange -> {
            geminiCalls.incrementAndGet();
            geminiBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] answer = geminiReply.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type",
                    geminiReply.startsWith("data:") ? "text/event-stream" : "application/json");
            exchange.sendResponseHeaders(200, answer.length);
            exchange.getResponseBody().write(answer);
            exchange.close();
        });
        gemini.start();
    }

    @AfterEach
    void stop() {
        main.stop(0);
        gemini.stop(0);
    }

    private ClaudeService service(boolean withFallback) {
        String mainUrl = "http://127.0.0.1:" + main.getAddress().getPort() + "/api";
        String geminiUrl = "http://127.0.0.1:" + gemini.getAddress().getPort() + "/openai";
        LlmProperties properties = new LlmProperties("sk-deepseek", "deepseek-flash", "v1", "v1", mainUrl, null,
                withFallback ? "gem-key" : "", "gemini-test", geminiUrl);
        GeminiClient client = new GeminiClient(geminiUrl, properties.fallbackApiKey(), "gemini-test");
        return new ClaudeService(new LlmConfig().anthropicClient(properties), properties, usage, client);
    }

    private static String geminiJson(String content) {
        return "{\"choices\":[{\"message\":{\"content\":\"" + content.replace("\"", "\\\"")
                + "\"}}],\"usage\":{\"prompt_tokens\":50,\"completion_tokens\":12}}";
    }

    private static String geminiStream(String... pieces) {
        StringBuilder events = new StringBuilder();
        for (String piece : pieces) {
            events.append("data: {\"choices\":[{\"delta\":{\"content\":\"").append(piece.replace("\"", "\\\""))
                    .append("\"}}]}\n\n");
        }
        events.append("data: {\"choices\":[],\"usage\":{\"prompt_tokens\":50,\"completion_tokens\":12}}\n\n");
        return events.append("data: [DONE]\n\n").toString();
    }

    @Test
    void geminiAnswersWhenDeepSeekFailsAndTheUsageNamesGemini() {
        geminiReply = geminiJson(SENTENCE_JSON);

        Explanation explanation = service(true).explainSentence("I gave up after a week.");

        assertThat(explanation.meaning()).isEqualTo("I stopped trying after a week.");
        assertThat(geminiCalls.get()).isEqualTo(1);
        assertThat(geminiBody.get()).contains("\"model\":\"gemini-test\"").contains("Answer with ONLY one JSON object");
        verify(usage).record(Feature.SENTENCE, "gemini-test", 50, 12);
    }

    @Test
    void withoutAGeminiKeyTheDeepSeekErrorIsThrown() {
        assertThatThrownBy(() -> service(false).explainSentence("I gave up.")).isInstanceOf(RuntimeException.class);
        assertThat(geminiCalls.get()).isZero();
    }

    @Test
    void geminiAnswersAStreamedSentenceWhenDeepSeekFailsBeforeAnyText() {
        geminiReply = geminiStream(SENTENCE_JSON.substring(0, 30), SENTENCE_JSON.substring(30));
        List<String> pieces = new ArrayList<>();

        Explanation explanation = service(true).explainSentenceStreaming("I gave up after a week.", pieces::add);

        assertThat(explanation.meaning()).isEqualTo("I stopped trying after a week.");
        assertThat(String.join("", pieces)).isEqualTo(SENTENCE_JSON);
        verify(usage).record(Feature.SENTENCE, "gemini-test", 50, 12);
    }

    @Test
    void afterStreamedTextTheErrorIsShownAndGeminiIsNotCalled() {
        geminiReply = geminiJson(SENTENCE_JSON);
        mainStatus = 200;
        // Text arrives, then the stream ends without a message_stop: the answer is cut.
        mainBody = "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"m\",\"type\":\"message\","
                + "\"role\":\"assistant\",\"model\":\"deepseek-flash\",\"content\":[],\"stop_reason\":null,"
                + "\"stop_sequence\":null,\"usage\":{\"input_tokens\":10,\"output_tokens\":1}}}\n\n"
                + "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,"
                + "\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n"
                + "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,"
                + "\"delta\":{\"type\":\"text_delta\",\"text\":\"{\\\"sourceLang\\\":\\\"en\\\",\\\"sum\"}}\n\n";
        List<String> pieces = new ArrayList<>();

        assertThatThrownBy(() -> service(true).explainSentenceStreaming("I gave up.", pieces::add))
                .isInstanceOf(RuntimeException.class);

        assertThat(pieces).isNotEmpty();
        assertThat(geminiCalls.get()).isZero();
    }
}
