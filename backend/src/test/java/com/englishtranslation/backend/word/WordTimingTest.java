package com.englishtranslation.backend.word;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

class WordTimingTest {

    private static final long MS = 1_000_000L;

    private final AtomicLong now = new AtomicLong();

    private final WordTiming timing = new WordTiming(now::get);

    private void pass(long millis) {
        now.addAndGet(millis * MS);
    }

    @Test
    void newWordLineHasEveryStepInOrderWithTheRetry() {
        timing.word("scribbling");
        timing.time("lookup", () -> pass(2));
        timing.time("lookup", () -> pass(1));
        timing.time("gate", () -> pass(1));
        timing.time("llm", () -> pass(9200));
        timing.time("retry", () -> pass(8800));
        timing.needsReview();
        timing.time("save", () -> pass(5));
        timing.ok(WordAnswer.Origin.NEW);

        assertThat(timing.line()).isEqualTo("word word=scribbling origin=new lookup=3ms gate=1ms llm=9200ms"
                + " retry=8800ms save=5ms total=18009ms needs_review=true result=ok");
    }

    @Test
    void aCachedPhraseHasOnlyItsLookupAndNoSpaces() {
        timing.word("give up");
        timing.time("lookup", () -> pass(4));
        timing.ok(WordAnswer.Origin.NOT_A_WORD);

        assertThat(timing.line()).isEqualTo("word word=give_up origin=not-a-word lookup=4ms total=4ms result=ok");
    }

    @Test
    void aFailedRequestNamesTheError() {
        timing.word("abstain");
        timing.failed(new IllegalStateException("boom"));

        assertThat(timing.line()).isEqualTo("word word=abstain origin=- total=0ms result=IllegalStateException");
    }
}
