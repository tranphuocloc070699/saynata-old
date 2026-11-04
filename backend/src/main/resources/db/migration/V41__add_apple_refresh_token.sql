-- TASK-112.3: revoke Sign in with Apple tokens when the account is deleted (App Store rule).
-- apple_refresh_token: the refresh token Apple gave for the sign-in's authorization code, encrypted with
-- AES-256-GCM (APPLE_TOKEN_ENCRYPTION_KEY), base64. Null for Google, and for Apple accounts that signed in before
-- this change or while the Apple keys were not set.
-- apple_client_id: the bundle ID the token was made for (iOS or Mac app); the revoke call must use the same one.
ALTER TABLE user_identity ADD COLUMN apple_refresh_token TEXT;
ALTER TABLE user_identity ADD COLUMN apple_client_id VARCHAR(255);
