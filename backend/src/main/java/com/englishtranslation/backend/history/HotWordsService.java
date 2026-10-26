package com.englishtranslation.backend.history;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/** The words many people looked up lately, for the homepage chips. Kept in memory for a few minutes. */
@Service
public class HotWordsService {

    static final int MAX_LIMIT = 20;
    private static final Duration WINDOW = Duration.ofDays(14);
    private static final Duration KEEP = Duration.ofMinutes(10);

    private final HistoryItemRepository history;
    private final int minUsers;

    private List<String> cached = List.of();
    private Instant cachedAt = Instant.EPOCH;

    public HotWordsService(HistoryItemRepository history, @Value("${app.hot-words.min-users:2}") int minUsers) {
        this.history = history;
        this.minUsers = minUsers;
    }

    public synchronized List<String> hot(int limit) {
        Instant now = Instant.now();
        if (cachedAt.plus(KEEP).isBefore(now)) {
            cached = history.hotWords(now.minus(WINDOW), minUsers, MAX_LIMIT);
            cachedAt = now;
        }
        return cached.subList(0, Math.min(Math.max(limit, 0), cached.size()));
    }

    synchronized void forget() {
        cachedAt = Instant.EPOCH;
    }
}
