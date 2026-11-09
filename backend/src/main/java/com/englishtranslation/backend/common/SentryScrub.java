package com.englishtranslation.backend.common;

import io.sentry.SentryEvent;
import io.sentry.SentryOptions;
import io.sentry.protocol.Request;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Privacy rule for Sentry (TASK-128): looked-up text never leaves the server. An error event keeps the path but
 * loses the query string, and the word in /api/words/{word} or /api/terms/{text} becomes a placeholder.
 */
@Component
public class SentryScrub implements SentryOptions.BeforeSendCallback {

    private static final Pattern TEXT_PATH = Pattern.compile("/api/(words|terms)/(?!hot(?:[/?#]|$))[^/?#]+");

    static String scrubUrl(String url) {
        if (url == null) return null;
        int query = url.indexOf('?');
        String path = query < 0 ? url : url.substring(0, query);
        return TEXT_PATH.matcher(path).replaceAll("/api/$1/:text");
    }

    @Override
    public SentryEvent execute(SentryEvent event, io.sentry.Hint hint) {
        Request request = event.getRequest();
        if (request != null) {
            request.setUrl(scrubUrl(request.getUrl()));
            request.setQueryString(null);
            request.setData(null);
            request.setCookies(null);
        }
        return event;
    }
}
