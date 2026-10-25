package com.englishtranslation.backend.history;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** One word or sentence in a user's History. A removed one stays as a tombstone (deleted = true). Key: (user, kind, textKey). */
@Entity
@Table(name = "history_item")
public class HistoryItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "kind", nullable = false, length = 10)
    private String kind;

    @Column(name = "text_key", nullable = false, length = 500)
    private String textKey;

    @Column(name = "text", nullable = false, length = 500)
    private String text;

    @Column(name = "preview", nullable = false, length = 300)
    private String preview;

    @Column(name = "chip", length = 40)
    private String chip;

    /** The client time of the last change (last-write-wins); History is shown newest first by it. */
    @Column(name = "at", nullable = false)
    private Instant at;

    @Column(name = "deleted", nullable = false)
    private boolean deleted;

    @Column(name = "change_seq", nullable = false)
    private long changeSeq;

    protected HistoryItem() {
    }

    public HistoryItem(Long userId, String kind, String textKey) {
        this.userId = userId;
        this.kind = kind;
        this.textKey = textKey;
        this.text = textKey;
        this.preview = "";
        this.at = Instant.EPOCH;
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

    public void apply(String text, String preview, String chip, Instant at, boolean deleted, long seq) {
        this.text = text;
        this.preview = preview;
        this.chip = chip;
        this.at = at;
        this.deleted = deleted;
        this.changeSeq = seq;
    }
}
