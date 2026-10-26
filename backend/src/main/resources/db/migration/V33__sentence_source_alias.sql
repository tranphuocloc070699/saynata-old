-- TASK-114.1: text typed in another language. The English part is saved once under the key of the English version
-- (so two Vietnamese wordings with the same English share one row). This table remembers which row a typed text
-- belongs to, so the same typed text is a cache hit without asking Claude for its English version again.
-- alias_key = sha256("sentence-src" | promptVersion | typedText); source_lang and word_match are about the typed text.
CREATE TABLE sentence_source_alias (
    alias_key   VARCHAR(64)              PRIMARY KEY,
    cache_key   VARCHAR(64)              NOT NULL,
    source_lang VARCHAR(8)               NOT NULL,
    word_match  VARCHAR(64)              NOT NULL DEFAULT '',
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_sentence_source_alias_cache_key ON sentence_source_alias (cache_key);
