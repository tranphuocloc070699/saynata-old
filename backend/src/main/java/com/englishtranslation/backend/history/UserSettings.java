package com.englishtranslation.backend.history;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** The settings that follow the account (TASK-93.3). One row per user, made on first use with the defaults. */
@Entity
@Table(name = "user_settings")
public class UserSettings {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "target_language", nullable = false, length = 20)
    private String targetLanguage = "vi";

    /** "collapsed", "alwaysOpen" or "remember". */
    @Column(name = "show_translation", nullable = false, length = 20)
    private String showTranslation = "remember";

    @Column(name = "sync_history", nullable = false)
    private boolean syncHistory = true;

    /** The client time of the last "clear all"; an add from before it is ignored. */
    @Column(name = "history_cleared_at")
    private Instant historyClearedAt;

    protected UserSettings() {
    }

    public UserSettings(Long userId) {
        this.userId = userId;
    }

    public String getTargetLanguage() {
        return targetLanguage;
    }

    public void setTargetLanguage(String targetLanguage) {
        this.targetLanguage = targetLanguage;
    }

    public String getShowTranslation() {
        return showTranslation;
    }

    public void setShowTranslation(String showTranslation) {
        this.showTranslation = showTranslation;
    }

    public boolean isSyncHistory() {
        return syncHistory;
    }

    public void setSyncHistory(boolean syncHistory) {
        this.syncHistory = syncHistory;
    }

    public Instant getHistoryClearedAt() {
        return historyClearedAt;
    }

    public void setHistoryClearedAt(Instant historyClearedAt) {
        this.historyClearedAt = historyClearedAt;
    }
}
