package com.englishtranslation.backend.liked;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.common.ApiException;
import com.englishtranslation.backend.common.ChangeSequence;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Liked words and sentences of one user. No Claude call here, so ClaudeGate is not involved.
 * A removed item stays as a tombstone (deleted = true) so /api/sync can tell the other devices (TASK-93.3).
 */
@Service
public class LikedService {

    public static final int MAX_TEXT = 500;
    public static final int MAX_PREVIEW = 300;
    public static final int MAX_CHIP = 40;
    static final int MAX_ITEMS = 5000;

    private final LikedItemRepository items;
    private final Clock clock;
    private final ChangeSequence sequence;

    public LikedService(LikedItemRepository items, Clock clock, ChangeSequence sequence) {
        this.items = items;
        this.clock = clock;
        this.sequence = sequence;
    }

    public List<LikedItemView> list(long userId) {
        return items.findByUserIdAndDeletedFalseOrderByAtDescIdDesc(userId).stream().map(LikedItemView::of).toList();
    }

    public long count(long userId) {
        return items.countByUserIdAndDeletedFalse(userId);
    }

    /** Every liked row (tombstones too) with a change number above {@code since}, oldest change first. */
    public List<LikedItem> changesSince(long userId, long since) {
        return items.findByUserIdAndChangeSeqGreaterThanOrderByChangeSeqAsc(userId, since);
    }

    /** Likes an item. Liking the same item again keeps one row and only updates its text and preview. */
    public LikedItemView like(long userId, LikedRequest request) {
        String kind = checkKind(request.kind());
        String text = request.text() == null ? "" : request.text().strip();
        if (text.isEmpty() || text.length() > MAX_TEXT) {
            throw bad("invalid_text", "Text must be 1-" + MAX_TEXT + " characters.");
        }
        String preview = request.preview() == null ? "" : request.preview().strip();
        if (preview.length() > MAX_PREVIEW) {
            throw bad("invalid_preview", "Preview must be at most " + MAX_PREVIEW + " characters.");
        }
        String textKey = key(kind, text);

        LikedItem existing = items.findByUserIdAndKindAndTextKey(userId, kind, textKey).orElse(null);
        if (existing != null && !existing.isDeleted()) {
            existing.apply(text, preview, existing.getChip(), existing.getAt(), false, sequence.next());
            return LikedItemView.of(items.save(existing));
        }
        if (existing == null && items.countByUserIdAndDeletedFalse(userId) >= MAX_ITEMS) {
            throw bad("liked_limit_reached", "You can like at most " + MAX_ITEMS + " items. Remove some first.");
        }
        try {
            LikedItem row = existing != null ? existing : LikedItem.create(userId, kind, textKey, clock.instant());
            row.apply(text, preview, null, clock.instant(), false, sequence.next());
            return LikedItemView.of(items.saveAndFlush(row));
        } catch (DataIntegrityViolationException e) {
            // Two requests liked the same item at the same moment: the other one saved it first.
            LikedItem saved = items.findByUserIdAndKindAndTextKey(userId, kind, textKey).orElseThrow(() -> e);
            saved.apply(text, preview, saved.getChip(), saved.getAt(), false, sequence.next());
            return LikedItemView.of(items.save(saved));
        }
    }

    /** Removes an item (it stays as a tombstone). Nothing there is not an error. */
    public void unlike(long userId, String kind, String text) {
        String checkedKind = checkKind(kind);
        remove(userId, checkedKind, text == null ? "" : text, clock.instant());
    }

    /**
     * One like from /api/sync, last-write-wins by the client time {@code at}: a change older than the row is ignored.
     * Input is already checked by SyncService. At the {@link #MAX_ITEMS} limit a new like is skipped, not an error,
     * so one full account cannot block the whole batch.
     */
    public void syncAdd(long userId, String kind, String text, String preview, String chip, Instant at) {
        LikedItem row = items.findByUserIdAndKindAndTextKey(userId, kind, key(kind, text)).orElse(null);
        if (row != null && at.isBefore(row.getAt())) {
            return;
        }
        if (row == null) {
            if (items.countByUserIdAndDeletedFalse(userId) >= MAX_ITEMS) {
                return;
            }
            row = LikedItem.create(userId, kind, key(kind, text), at);
        }
        row.apply(text, preview, chip, at, false, sequence.next());
        items.save(row);
    }

    /** One unlike from /api/sync. Without a row it still leaves a tombstone, so an older like that arrives later loses. */
    public void syncRemove(long userId, String kind, String text, Instant at) {
        remove(userId, kind, text, at);
    }

    private void remove(long userId, String kind, String text, Instant at) {
        String textKey = key(kind, text);
        LikedItem row = items.findByUserIdAndKindAndTextKey(userId, kind, textKey).orElse(null);
        if (row == null) {
            row = LikedItem.create(userId, kind, textKey, at);
            row.apply(row.getText(), "", null, at, true, sequence.next());
        } else if (at.isBefore(row.getAt())) {
            return;
        } else if (row.isDeleted()) {
            // Already removed: keep the newer client time, so an add between the two times still loses.
            row.apply(row.getText(), row.getPreview(), row.getChip(), at, true, row.getChangeSeq());
        } else {
            row.apply(row.getText(), row.getPreview(), row.getChip(), at, true, sequence.next());
        }
        items.save(row);
    }

    public static String checkKind(String kind) {
        if ("word".equals(kind) || "sentence".equals(kind)) {
            return kind;
        }
        throw bad("invalid_kind", "Kind must be \"word\" or \"sentence\".");
    }

    /** Word: same as the word lookup (trim, one space, lowercase). Sentence: trimmed, case kept. */
    public static String key(String kind, String text) {
        return kind.equals("word") ? CacheKeys.normalizeWord(text) : text.strip();
    }

    private static ApiException bad(String code, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, code, message);
    }
}
