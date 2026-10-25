package com.englishtranslation.backend.translation;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.function.LongSupplier;
import java.util.function.Supplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Times the steps of one sentence request and logs them as one line (TASK-113), so a slow answer shows which step was
 * slow. For example:
 *
 * <pre>
 * sentence key=3fa9c2d1 cache=miss lang=vi stream=true lookup=4ms gate=2ms llm_first_token=1840ms llm=4200ms line=1900ms save=12ms total=6150ms result=ok
 * </pre>
 *
 * A step that did not run is left out. The line has no sentence text, only the start of the cache key, because a
 * sentence can be personal. {@code total} is the time on the server; the app's wait minus {@code total} is the network.
 */
final class SentenceTiming {

    private static final Logger log = LoggerFactory.getLogger(SentenceTiming.class);

    private static final int KEY_PREFIX = 8;

    private final LongSupplier nanoClock;
    private final long startedAt;
    private final String lang;
    private final boolean stream;
    private final Map<String, Long> stepNanos = new LinkedHashMap<>();
    private long llmStartedAt = -1;
    private long firstTokenNanos = -1;
    private String key = "-";
    private String cache = "-";
    private String result = "error";

    SentenceTiming(TargetLanguage lang, boolean stream) {
        this(lang, stream, System::nanoTime);
    }

    /** The clock can be replaced in a test. */
    SentenceTiming(TargetLanguage lang, boolean stream, LongSupplier nanoClock) {
        this.nanoClock = nanoClock;
        this.startedAt = nanoClock.getAsLong();
        this.lang = lang.name().toLowerCase();
        this.stream = stream;
    }

    /** Runs one step and adds its time. A step that runs twice (two lookups) adds up. */
    <T> T time(String step, Supplier<T> work) {
        long start = nanoClock.getAsLong();
        if (step.equals("llm")) {
            llmStartedAt = start;
        }
        try {
            return work.get();
        } finally {
            stepNanos.merge(step, nanoClock.getAsLong() - start, Long::sum);
        }
    }

    void time(String step, Runnable work) {
        time(step, () -> {
            work.run();
            return null;
        });
    }

    /** The LLM sent its first piece of text: how long the gateway and the model took to start answering. */
    void firstToken() {
        if (firstTokenNanos < 0 && llmStartedAt >= 0) {
            firstTokenNanos = nanoClock.getAsLong() - llmStartedAt;
        }
    }

    void key(String cacheKey) {
        this.key = cacheKey.length() > KEY_PREFIX ? cacheKey.substring(0, KEY_PREFIX) : cacheKey;
    }

    /** hit, loose-hit, miss, personal or not-cached. */
    void cache(String cache) {
        this.cache = cache;
    }

    void ok() {
        this.result = "ok";
    }

    void failed(Exception e) {
        this.result = e.getClass().getSimpleName();
    }

    String line() {
        StringBuilder line = new StringBuilder("sentence key=").append(key)
                .append(" cache=").append(cache)
                .append(" lang=").append(lang)
                .append(" stream=").append(stream);
        stepNanos.forEach((step, nanos) -> {
            if (step.equals("llm") && firstTokenNanos >= 0) {
                line.append(" llm_first_token=").append(millis(firstTokenNanos)).append("ms");
            }
            line.append(' ').append(step).append('=').append(millis(nanos)).append("ms");
        });
        return line.append(" total=").append(millis(nanoClock.getAsLong() - startedAt)).append("ms")
                .append(" result=").append(result)
                .toString();
    }

    void log() {
        log.info(line());
    }

    private static long millis(long nanos) {
        return nanos / 1_000_000;
    }
}
