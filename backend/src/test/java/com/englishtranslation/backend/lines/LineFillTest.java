package com.englishtranslation.backend.lines;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;

/** The background fill: off the request thread in production, in the caller's thread when turned off (tests). */
class LineFillTest {

    @Test
    void inTheBackgroundAFillRunsOnItsOwnThread() throws Exception {
        CompletableFuture<String> thread = new CompletableFuture<>();
        new LineFill(true).run(() -> thread.complete(Thread.currentThread().getName()));
        assertThat(thread.get(5, TimeUnit.SECONDS)).startsWith("line-fill-");
    }

    @Test
    void turnedOffAFillRunsAtOnce() {
        String[] name = new String[1];
        new LineFill(false).run(() -> name[0] = Thread.currentThread().getName());
        assertThat(name[0]).isEqualTo(Thread.currentThread().getName());
    }
}
