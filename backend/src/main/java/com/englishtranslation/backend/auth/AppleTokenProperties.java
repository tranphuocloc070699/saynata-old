package com.englishtranslation.backend.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Settings for talking to Apple's token endpoints (app.auth.apple-tokens.* in application.properties, TASK-112.3):
 * exchanging the sign-in's authorization code for a refresh token, and revoking it when the account is deleted.
 *
 * @param teamId        the Apple Developer team ID (APPLE_TEAM_ID)
 * @param keyId         the ID of the "Sign in with Apple" key (APPLE_KEY_ID)
 * @param privateKey    that key's .p8 file, as PEM text; "\n" written as two characters is allowed (APPLE_PRIVATE_KEY)
 * @param encryptionKey 32 random bytes, base64, that encrypt the stored refresh tokens (APPLE_TOKEN_ENCRYPTION_KEY)
 * @param baseUrl       Apple's address; tests point it at a fake server (APPLE_AUTH_BASE_URL)
 */
@ConfigurationProperties(prefix = "app.auth.apple-tokens")
public record AppleTokenProperties(String teamId, String keyId, String privateKey, String encryptionKey,
        String baseUrl) {

    /** All four secrets are set. Otherwise the exchange and the revoke are off and sign-in works as before. */
    public boolean isConfigured() {
        return notBlank(teamId) && notBlank(keyId) && notBlank(privateKey) && notBlank(encryptionKey);
    }

    private static boolean notBlank(String value) {
        return value != null && !value.isBlank();
    }
}
