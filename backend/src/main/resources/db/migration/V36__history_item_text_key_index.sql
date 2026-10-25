-- TASK-116: suggestions are ranked by how many people looked a word up. The few candidate rows are counted
-- by text_key (one IN query), so this index keeps it fast.
CREATE INDEX idx_history_item_kind_text_key ON history_item (kind, text_key);
