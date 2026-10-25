package com.englishtranslation.backend.liked;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** One word or sentence a user starred. The key is (user, kind, textKey). */
@Entity
@Table(name = "liked_item")
public class LikedItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** "word" or "sentence". */
    @Column(name = "kind", nullable = false, length = 10)
    private String kind;

    /** The normalized text, used only to find the same item again. */
    @Column(name = "text_key", nullable = false, length = 500)
    private String textKey;

    /** The text as the user saw it. */
    @Column(name = "text", nullable = false, length = 500)
    private String text;

    @Column(name = "preview", nullable = false, length = 300)
    private String preview;

    @Column(name = "chip", length = 40)
    private String chip;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    /** The client time of the last change, for last-write-wins (TASK-93.3). */
    @Column(name = "at", nullable = false)
    private Instant at;

    /** A removed item stays as a tombstone, so the other devices remove it too. */
    @Column(name = "deleted", nullable = false)
    private boolean deleted;

    /** From sync_change_seq; the sync cursor is the biggest one a client has seen. */
    @Column(name = "change_seq", nullable = false)
    private long changeSeq;

    protected LikedItem() {
    }

    public LikedItem(Long userId, String kind, String textKey, String text, String preview, Instant createdAt) {
        this.userId = userId;
        this.kind = kind;
        this.textKey = textKey;
        this.text = text;
        this.preview = preview;
        this.createdAt = createdAt;
        this.at = createdAt;
        this.changeSeq = 1;
    }

    public String getKind() {
        return kind;
    }

    public String getText() {
        return text;
    }

    public String getPreview() {
        return preview;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public String getChip() {
        return chip;
    }

    public Instant getAt() {
        return at;
    }

    public boolean isDeleted() {
        return deleted;
    }

    public long getChangeSeq() {
        return changeSeq;
    }

    public String getTextKey() {
        return textKey;
    }

    /** Sets the live (or deleted) state of this item at client time {@code at}, as change number {@code seq}. */
    public void apply(String text, String preview, String chip, Instant at, boolean deleted, long seq) {
        this.text = text;
        this.preview = preview;
        this.chip = chip;
        this.at = at;
        this.deleted = deleted;
        this.changeSeq = seq;
    }

    public static LikedItem create(Long userId, String kind, String textKey, Instant now) {
        return new LikedItem(userId, kind, textKey, textKey, "", now);
    }
}
