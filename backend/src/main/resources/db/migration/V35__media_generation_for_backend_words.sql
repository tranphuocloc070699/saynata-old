-- TASK-115.2: AI pictures for backend words (pipeline: uv run pipeline media-ai --backend).
-- A media_generation row now belongs to EITHER a bundled sense (sense_id, as before) OR a backend-word sense
-- (lookup_media_id = word_lookup_media.id). The backend still does not read this table.
ALTER TABLE media_generation ALTER COLUMN sense_id DROP NOT NULL;
ALTER TABLE media_generation ADD COLUMN lookup_media_id BIGINT REFERENCES word_lookup_media (id) ON DELETE CASCADE;
ALTER TABLE media_generation ADD CONSTRAINT media_generation_one_owner
    CHECK ((sense_id IS NULL) <> (lookup_media_id IS NULL));
CREATE INDEX idx_media_generation_lookup ON media_generation (lookup_media_id, created_at DESC);
