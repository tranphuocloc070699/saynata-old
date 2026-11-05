-- Set when a refresh token was swapped for a new pair (not when it was signed out or revoked with all others).
-- A copy of it sent again within a short window (a lost answer, two app processes refreshing at once) gets a new
-- pair instead of ending every session of the user (AuthService.refresh, 2026-11-05).
ALTER TABLE refresh_token ADD COLUMN rotated_at TIMESTAMP WITH TIME ZONE;
