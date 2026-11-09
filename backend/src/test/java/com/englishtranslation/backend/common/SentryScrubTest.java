package com.englishtranslation.backend.common;

import static org.assertj.core.api.Assertions.assertThat;

import io.sentry.Hint;
import io.sentry.SentryEvent;
import io.sentry.protocol.Request;
import org.junit.jupiter.api.Test;

class SentryScrubTest {

    @Test
    void removesTheLookedUpWordAndTheQuery() {
        assertThat(SentryScrub.scrubUrl("https://api.saynata.com/api/words/give%20up?cachedOnly=true"))
                .isEqualTo("https://api.saynata.com/api/words/:text");
        assertThat(SentryScrub.scrubUrl("/api/terms/node.js")).isEqualTo("/api/terms/:text");
        assertThat(SentryScrub.scrubUrl("/api/suggest?q=hel")).isEqualTo("/api/suggest");
    }

    @Test
    void keepsOtherPaths() {
        assertThat(SentryScrub.scrubUrl("/api/words/hot?limit=10")).isEqualTo("/api/words/hot");
        assertThat(SentryScrub.scrubUrl("/api/translations/stream")).isEqualTo("/api/translations/stream");
    }

    @Test
    void cleansTheRequestOfAnEvent() {
        Request request = new Request();
        request.setUrl("/api/words/hello");
        request.setQueryString("q=hello");
        request.setData("{\"text\":\"hello\"}");
        SentryEvent event = new SentryEvent();
        event.setRequest(request);

        Request out = new SentryScrub().execute(event, new Hint()).getRequest();

        assertThat(out.getUrl()).isEqualTo("/api/words/:text");
        assertThat(out.getQueryString()).isNull();
        assertThat(out.getData()).isNull();
    }
}
