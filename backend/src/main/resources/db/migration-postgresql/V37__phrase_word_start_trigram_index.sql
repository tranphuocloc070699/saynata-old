-- TASK-116: a phrase can match from any of its words ("up" finds "give up"). The query is
-- LOWER(source_text) LIKE '% up%', which a normal index cannot use; a trigram index can.
-- Postgres only (the tests run on H2, which reads only db/migration). pg_trgm ships with Postgres (contrib) and
-- is a trusted extension. If it is not available, the app still starts and the query is only slower.
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE INDEX IF NOT EXISTS idx_sentence_translation_source_trgm
        ON sentence_translation USING gin (LOWER(source_text) gin_trgm_ops);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_trgm not available, phrase word-start search has no index: %', SQLERRM;
END
$$;
