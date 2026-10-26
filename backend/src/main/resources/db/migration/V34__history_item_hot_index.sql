-- Hot words on the homepage: the recent lookups of everyone, by kind and time.
CREATE INDEX idx_history_item_kind_at ON history_item (kind, at);
