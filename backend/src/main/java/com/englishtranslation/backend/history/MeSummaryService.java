package com.englishtranslation.backend.history;

import com.englishtranslation.backend.auth.UserIdentity;
import com.englishtranslation.backend.auth.UserIdentityRepository;
import com.englishtranslation.backend.claude.ClaudeUsageRepository;
import com.englishtranslation.backend.limits.LimitProperties;
import com.englishtranslation.backend.liked.LikedService;
import com.englishtranslation.backend.user.User;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import org.springframework.stereotype.Service;

/** The account page numbers of GET /api/me (TASK-93.3). */
@Service
public class MeSummaryService {

        /**
         * @param signInMethod "email", "google" or "apple"
         * @param aiUsedToday  new Claude calls of this user in the last 24 hours (the
         *                     same window as the daily limit)
         * @param aiLimitToday the daily limit per user
         */
        public record MeView(Long id, String email, String signInMethod, Instant memberSince, long historyCount,
                        long likedCount, long aiUsedToday, int aiLimitToday) {
        }

        private final UserIdentityRepository identities;
        private final HistoryItemRepository history;
        private final LikedService liked;
        private final ClaudeUsageRepository usage;
        private final LimitProperties limits;
        private final Clock clock;

        public MeSummaryService(UserIdentityRepository identities, HistoryItemRepository history, LikedService liked,
                        ClaudeUsageRepository usage, LimitProperties limits, Clock clock) {
                this.identities = identities;
                this.history = history;
                this.liked = liked;
                this.usage = usage;
                this.limits = limits;
                this.clock = clock;
        }

        public MeView summary(User user) {
                String method = identities.findFirstByUserIdOrderByCreatedAtAsc(user.getId())
                                .map(UserIdentity::getProvider).map(p -> p.name().toLowerCase(java.util.Locale.ROOT))
                                .orElse("email");
                Instant dayAgo = clock.instant().minus(Duration.ofHours(24));
                return new MeView(user.getId(), user.getEmail(), method, user.getCreatedAt(),
                                history.countByUserIdAndDeletedFalse(user.getId()), liked.count(user.getId()),
                                usage.countByUserIdAndCreatedAtGreaterThanEqual(user.getId(), dayAgo),
                                limits.claudePerUserDay().max());
        }
}
