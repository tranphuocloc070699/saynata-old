package com.englishtranslation.backend.history;

import com.englishtranslation.backend.common.ApiException;
import com.englishtranslation.backend.common.ChangeSequence;
import com.englishtranslation.backend.history.SyncModels.Changes;
import com.englishtranslation.backend.history.SyncModels.SyncItem;
import com.englishtranslation.backend.history.SyncModels.SyncOp;
import com.englishtranslation.backend.history.SyncModels.SyncRequest;
import com.englishtranslation.backend.history.SyncModels.SyncResponse;
import com.englishtranslation.backend.liked.LikedItem;
import com.englishtranslation.backend.liked.LikedService;
import com.englishtranslation.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * POST /api/sync: apply a batch of changes from one device, then return everything that changed since the
 * client's cursor (TASK-93.3, doc-22). Last-write-wins by the client time {@code at}; removes and "clear all"
 * stay as tombstones. The user row is locked, so two syncs of one account never run at the same time.
 * No Claude call here, so ClaudeGate is not involved.
 */
@Service
public class SyncService {

    public static final int MAX_OPS = 200;
    public static final int MAX_HISTORY = 1000;
    private static final Set<String> TYPES =
            Set.of("history_add", "history_remove", "history_clear", "liked_add", "liked_remove");

    private final UserRepository users;
    private final HistoryItemRepository history;
    private final LikedService liked;
    private final SettingsService settings;
    private final ChangeSequence sequence;
    private final Clock clock;

    public SyncService(UserRepository users, HistoryItemRepository history, LikedService liked,
            SettingsService settings, ChangeSequence sequence, Clock clock) {
        this.users = users;
        this.history = history;
        this.liked = liked;
        this.settings = settings;
        this.sequence = sequence;
        this.clock = clock;
    }

    @Transactional
    public SyncResponse sync(long userId, SyncRequest request) {
        long since = request.since() == null ? 0 : request.since();
        if (since < 0) {
            throw bad("invalid_since", "since must be 0 or a cursor from an earlier answer.");
        }
        List<SyncOp> ops = request.ops() == null ? List.of() : request.ops();
        if (ops.size() > MAX_OPS) {
            throw bad("too_many_ops", "Send at most " + MAX_OPS + " changes in one request.");
        }
        Instant now = clock.instant();
        List<Checked> checked = new ArrayList<>();
        for (SyncOp op : ops) {
            checked.add(check(op, now));
        }
        // Oldest first, so the order inside one batch does not matter. The sort is stable: equal times keep their order.
        checked.sort(Comparator.comparing(Checked::at));

        users.findLockedById(userId).orElseThrow(() ->
                new ApiException(HttpStatus.UNAUTHORIZED, "sign_in_required", "Sign in to sync."));
        UserSettings account = settings.getOrCreate(userId);
        for (Checked op : checked) {
            apply(userId, account, op);
        }
        if (account.isSyncHistory()) {
            enforceCap(userId);
        }
        settings.save(account);

        List<SyncItem> historyChanges = new ArrayList<>();
        long cursor = since;
        if (account.isSyncHistory()) {
            for (HistoryItem item : history.findByUserIdAndChangeSeqGreaterThanOrderByChangeSeqAsc(userId, since)) {
                historyChanges.add(new SyncItem(item.getKind(), item.getText(), item.getPreview(), item.getChip(),
                        item.getAt(), item.isDeleted()));
                cursor = Math.max(cursor, item.getChangeSeq());
            }
        }
        List<SyncItem> likedChanges = new ArrayList<>();
        for (LikedItem item : liked.changesSince(userId, since)) {
            likedChanges.add(new SyncItem(item.getKind(), item.getText(), item.getPreview(), item.getChip(),
                    item.getAt(), item.isDeleted()));
            cursor = Math.max(cursor, item.getChangeSeq());
        }
        return new SyncResponse(new Changes(historyChanges, likedChanges), cursor);
    }

    private void apply(long userId, UserSettings account, Checked op) {
        switch (op.type()) {
            case "liked_add" -> liked.syncAdd(userId, op.kind(), op.text(), op.preview(), op.chip(), op.at());
            case "liked_remove" -> liked.syncRemove(userId, op.kind(), op.text(), op.at());
            default -> {
                if (account.isSyncHistory()) {
                    applyHistory(userId, account, op);
                }
            }
        }
    }

    private void applyHistory(long userId, UserSettings account, Checked op) {
        Instant clearedAt = account.getHistoryClearedAt();
        if (op.type().equals("history_clear")) {
            for (HistoryItem item : history.findByUserIdAndDeletedFalseOrderByAtAscIdAsc(userId)) {
                if (!item.getAt().isAfter(op.at())) {
                    item.apply(item.getText(), item.getPreview(), item.getChip(), op.at(), true, sequence.next());
                    history.save(item);
                }
            }
            if (clearedAt == null || op.at().isAfter(clearedAt)) {
                account.setHistoryClearedAt(op.at());
            }
            return;
        }
        boolean add = op.type().equals("history_add");
        if (add && clearedAt != null && !op.at().isAfter(clearedAt)) {
            return; // cleared on another device after this was added
        }
        String textKey = LikedService.key(op.kind(), op.text());
        HistoryItem row = history.findByUserIdAndKindAndTextKey(userId, op.kind(), textKey).orElse(null);
        if (row != null && op.at().isBefore(row.getAt())) {
            return;
        }
        if (add) {
            if (row == null) {
                row = new HistoryItem(userId, op.kind(), textKey);
            }
            row.apply(op.text(), op.preview(), op.chip(), op.at(), false, sequence.next());
        } else if (row == null) {
            // Nothing there yet: leave a tombstone, so an older add that arrives later loses.
            row = new HistoryItem(userId, op.kind(), textKey);
            row.apply(row.getText(), "", null, op.at(), true, sequence.next());
        } else if (row.isDeleted()) {
            row.apply(row.getText(), row.getPreview(), row.getChip(), op.at(), true, row.getChangeSeq());
        } else {
            row.apply(row.getText(), row.getPreview(), row.getChip(), op.at(), true, sequence.next());
        }
        history.save(row);
    }

    /** More than {@link #MAX_HISTORY} live items: the oldest ones become tombstones. */
    private void enforceCap(long userId) {
        history.flush();
        long extra = history.countByUserIdAndDeletedFalse(userId) - MAX_HISTORY;
        if (extra <= 0) {
            return;
        }
        for (HistoryItem item : history.findByUserIdAndDeletedFalseOrderByAtAscIdAsc(userId)) {
            if (extra-- <= 0) {
                break;
            }
            item.apply(item.getText(), item.getPreview(), item.getChip(), item.getAt(), true, sequence.next());
            history.save(item);
        }
    }

    private record Checked(String type, String kind, String text, String preview, String chip, Instant at) {
    }

    private static Checked check(SyncOp op, Instant now) {
        if (op == null || op.type() == null || !TYPES.contains(op.type())) {
            throw bad("invalid_op", "type must be one of " + TYPES + ".");
        }
        Instant at = op.at() == null || op.at().isAfter(now) ? now : op.at();
        if (op.type().equals("history_clear")) {
            return new Checked(op.type(), null, null, "", null, at);
        }
        String kind = LikedService.checkKind(op.kind());
        String text = op.text() == null ? "" : op.text().strip();
        if (text.isEmpty() || text.length() > LikedService.MAX_TEXT) {
            throw bad("invalid_text", "Text must be 1-" + LikedService.MAX_TEXT + " characters.");
        }
        String preview = op.preview() == null ? "" : op.preview().strip();
        if (preview.length() > LikedService.MAX_PREVIEW) {
            throw bad("invalid_preview", "Preview must be at most " + LikedService.MAX_PREVIEW + " characters.");
        }
        String chip = op.chip() == null || op.chip().isBlank() ? null : op.chip().strip();
        if (chip != null && chip.length() > LikedService.MAX_CHIP) {
            throw bad("invalid_chip", "Chip must be at most " + LikedService.MAX_CHIP + " characters.");
        }
        return new Checked(op.type(), kind, text, preview, chip, at);
    }

    private static ApiException bad(String code, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, code, message);
    }
}
