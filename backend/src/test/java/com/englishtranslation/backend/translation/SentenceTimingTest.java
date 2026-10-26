package com.englishtranslation.backend.translation;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

class SentenceTimingTest {

    private static final long MS = 1_000_000L;

    private final AtomicLong now = new AtomicLong();

    private SentenceTiming timing(boolean stream) {
        return new SentenceTiming(TargetLanguage.VI, stream, now::get);
    }

    private void pass(long millis) {
        now.addAndGet(millis * MS);
    }

    @Test
    void missLineHasEveryStepInOrderWithTheFirstToken() {
        SentenceTiming timing = timing(true);
        timing.key("3fa9c2d1aabbccdd");
        timing.time("lookup", () -> pass(4));
        timing.cache("miss");
        timing.time("gate", () -> pass(2));
        timing.time("llm", () -> {
            pass(1840);
            timing.firstToken();
            pass(500);
            timing.firstToken();
            pass(1860);
        });
        timing.time("save", () -> pass(12));
        timing.time("line", () -> pass(1900));
        timing.ok();

        assertThat(timing.line()).isEqualTo("sentence key=3fa9c2d1 cache=miss lang=vi stream=true lookup=4ms gate=2ms"
                + " llm_first_token=1840ms llm=4200ms save=12ms line=1900ms total=6118ms result=ok");
    }

    @Test
    void stepsThatDidNotRunAreLeftOutAndTwoLookupsAddUp() {
        SentenceTiming timing = timing(false);
        timing.key("abc");
        timing.time("lookup", () -> pass(3));
        timing.time("lookup", () -> pass(5));
        timing.cache("loose-hit");
        timing.ok();

        assertThat(timing.line())
                .isEqualTo("sentence key=abc cache=loose-hit lang=vi stream=false lookup=8ms total=8ms result=ok");
    }

    @Test
    void aFailedRequestNamesTheError() {
        SentenceTiming timing = timing(false);
        timing.failed(new IllegalStateException("boom"));

        assertThat(timing.line()).endsWith("result=IllegalStateException").doesNotContain("boom");
    }
}
