package com.englishtranslation.backend.translation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * Text typed in another language (TASK-114.1) points to the cache row of its English version. The row is keyed by the
 * English version, so many typed wordings share one English part; this alias keeps what is about the typed text itself:
 * its language and its word match.
 */
@Entity
@Table(name = "sentence_source_alias")
public class SentenceSourceAlias {

    @Id
    @Column(name = "alias_key", nullable = false, length = 64)
    private String aliasKey;

    @Column(name = "cache_key", nullable = false, length = 64)
    private String cacheKey;

    @Column(name = "source_lang", nullable = false, length = 8)
    private String sourceLang;

    /** The English headword for a single word ("sad" for "buồn"); "" when there is none. */
    @Column(name = "word_match", nullable = false, length = 64)
    private String wordMatch;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected SentenceSourceAlias() {
    }

    public SentenceSourceAlias(String aliasKey, String cacheKey, String sourceLang, String wordMatch) {
        this.aliasKey = aliasKey;
        this.cacheKey = cacheKey;
        this.sourceLang = sourceLang;
        this.wordMatch = wordMatch == null ? "" : wordMatch;
        this.createdAt = Instant.now();
    }

    public String getAliasKey() {
        return aliasKey;
    }

    public String getCacheKey() {
        return cacheKey;
    }

    public String getSourceLang() {
        return sourceLang;
    }

    public String getWordMatch() {
        return wordMatch;
    }
}
