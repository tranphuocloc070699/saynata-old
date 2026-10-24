package com.englishtranslation.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;

import com.englishtranslation.backend.prefill.PrefillProperties;
import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class PrefillScheduleTest {

    private static PrefillProperties withCron(String cron) {
        return new PrefillProperties(cron, List.of("sentence-words"), new BigDecimal("0.50"), Duration.ZERO, 3);
    }

    @Test
    void nextRunIsTheNextCronTimeInUtc() {
        AdminPrefillController.Schedule schedule = AdminPrefillController.schedule(
                withCron("0 0 20 * * *"), Instant.parse("2026-10-25T17:00:00Z"));

        assertThat(schedule.on()).isTrue();
        assertThat(schedule.nextRunAt()).isEqualTo(Instant.parse("2026-10-25T20:00:00Z"));
        assertThat(schedule.sources()).containsExactly("sentence-words");
    }

    @Test
    void afterTodaysRunTheNextIsTomorrow() {
        assertThat(AdminPrefillController.schedule(withCron("0 0 20 * * *"), Instant.parse("2026-10-25T21:00:00Z"))
                .nextRunAt()).isEqualTo(Instant.parse("2026-10-26T20:00:00Z"));
    }

    @Test
    void emptyOrBrokenCronIsOff() {
        Instant now = Instant.parse("2026-10-25T17:00:00Z");
        assertThat(AdminPrefillController.schedule(withCron(""), now).on()).isFalse();
        AdminPrefillController.Schedule broken = AdminPrefillController.schedule(withCron("every night"), now);
        assertThat(broken.on()).isFalse();
        assertThat(broken.nextRunAt()).isNull();
    }
}
