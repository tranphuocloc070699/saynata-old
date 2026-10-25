package com.englishtranslation.backend.word;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.function.LongSupplier;
import java.util.function.Supplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Times the steps of one word request and logs them as one line, like SentenceTiming does for sentences. For example:
 *
 * <pre>
 * word word=scribbling origin=new lookup=3ms gate=1ms llm=9200ms retry=8800ms save=5ms total=18010ms needs_review=true result=ok
 * </pre>
 *
 * A step that did not run is left out; {@code retry} is the second Claude call after the simple-words check failed.
 * Only a request that called Claude is logged at INFO. Bundled and cached answers (many per sentence, and every key
 * press while the user types) are logged at DEBUG. A single word is not personal, so the line has the word itself.
 */
final class WordTiming {

    private static final Logger log = LoggerFactory.getLogger(WordTiming.class);

    private final LongSupplier nanoClock;
    private final long startedAt;
    private final Map<String, Long> stepNanos = new LinkedHashMap<>();
    private String word = "-";
    private String origin = "-";
    private boolean needsReview;
    private String result = "error";

    WordTiming() {
        this(System::nanoTime);
    }

    /** The clock can be replaced in a test. */
    WordTiming(LongSupplier nanoClock) {
        this.nanoClock = nanoClock;
        this.startedAt = nanoClock.getAsLong();
    }

    /** Runs one step and adds its time. A step that runs twice (two lookups) adds up. */
    <T> T time(String step, Supplier<T> work) {
        long start = nanoClock.getAsLong();
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

    void word(String word) {
        this.word = word.replace(' ', '_');
    }

    void needsReview() {
        this.needsReview = true;
    }

    void ok(WordAnswer.Origin origin) {
        this.origin = origin.name().toLowerCase(Locale.ROOT).replace('_', '-');
        this.result = "ok";
    }

    void failed(Exception e) {
        this.result = e.getClass().getSimpleName();
    }

    String line() {
        StringBuilder line = new StringBuilder("word word=").append(word).append(" origin=").append(origin);
        stepNanos.forEach((step, nanos) -> line.append(' ').append(step).append('=').append(millis(nanos)).append("ms"));
        line.append(" total=").append(millis(nanoClock.getAsLong() - startedAt)).append("ms");
        if (needsReview) {
            line.append(" needs_review=true");
        }
        return line.append(" result=").append(result).toString();
    }

    void log() {
        if (stepNanos.containsKey("llm")) {
            log.info(line());
        } else if (log.isDebugEnabled()) {
            log.debug(line());
        }
    }

    private static long millis(long nanos) {
        return nanos / 1_000_000;
    }
}
