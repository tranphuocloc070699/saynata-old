package com.englishtranslation.backend.history;

import java.time.Instant;
import java.util.List;

/** The bodies of POST /api/sync (TASK-93.3). */
public final class SyncModels {

    private SyncModels() {
    }

    /**
     * @param since the cursor of the last sync (null or 0 = everything)
     * @param ops   what changed on this device; at most {@link SyncService#MAX_OPS}
     */
    public record SyncRequest(Long since, List<SyncOp> ops) {
    }

    /**
     * One change. {@code type}: history_add, history_remove, history_clear, liked_add, liked_remove.
     * {@code kind} and {@code text} are needed for every type except history_clear. {@code at} is the device time of
     * the change (ISO-8601); the newest {@code at} wins. Missing or in the future = now.
     */
    public record SyncOp(String type, String kind, String text, String preview, String chip, Instant at) {
    }

    /** One history or liked row. {@code deleted: true} is a tombstone: remove it on this device. */
    public record SyncItem(String kind, String text, String preview, String chip, Instant at, boolean deleted) {
    }

    public record Changes(List<SyncItem> history, List<SyncItem> liked) {
    }

    /** {@code cursor}: send it back as {@code since} next time. */
    public record SyncResponse(Changes changes, long cursor) {
    }
}
