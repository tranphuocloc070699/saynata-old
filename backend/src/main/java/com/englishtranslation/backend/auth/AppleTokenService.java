package com.englishtranslation.backend.auth;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Keeps each Apple account's refresh token so it can be revoked when the account is deleted (App Store rule,
 * TASK-112.3, doc-17).
 * <ul>
 * <li>Sign-in: the app sends Apple's authorization code; {@link #rememberSignIn} swaps it for a refresh token and
 * stores it encrypted on the {@link UserIdentity}. A failure is logged and the sign-in still works.</li>
 * <li>Delete: {@link #revokeAll} revokes every stored Apple token of the user (2 tries each). A failure is logged
 * and never stops the delete: the account must go even when Apple is down.</li>
 * </ul>
 * Off (both steps skipped, with a log line) while the Apple keys are not set ({@link AppleTokenProperties}).
 */
@Service
public class AppleTokenService {

    private static final Logger log = LoggerFactory.getLogger(AppleTokenService.class);
    static final int REVOKE_TRIES = 2;
    private static final int MAX_CODE_LENGTH = 4096;

    private final AppleTokenApi api;
    private final AppleTokenCipher cipher;
    private final UserIdentityRepository identities;

    public AppleTokenService(AppleTokenProperties properties, AppleTokenApi api, UserIdentityRepository identities) {
        this.api = api;
        this.identities = identities;
        this.cipher = properties.isConfigured() ? new AppleTokenCipher(properties.encryptionKey()) : null;
        if (cipher == null) {
            log.warn("Apple token keys are not set (APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, "
                    + "APPLE_TOKEN_ENCRYPTION_KEY). Apple tokens are NOT stored or revoked on account deletion.");
        }
    }

    public boolean isEnabled() {
        return cipher != null;
    }

    /** After an Apple sign-in: swap {@code authorizationCode} for a refresh token and store it. Never throws. */
    public void rememberSignIn(UserIdentity identity, String clientId, String authorizationCode) {
        if (identity == null || identity.getProvider() != SocialProvider.APPLE || !isEnabled()
                || clientId == null || authorizationCode == null || authorizationCode.isBlank()
                || authorizationCode.length() > MAX_CODE_LENGTH) {
            return;
        }
        try {
            String refreshToken = api.exchangeCode(clientId, authorizationCode.trim());
            identity.setAppleRefreshToken(cipher.encrypt(refreshToken), clientId);
            identities.save(identity);
        } catch (RuntimeException e) {
            log.warn("Could not get an Apple refresh token for user {}: {}", identity.getUserId(), e.getMessage());
        }
    }

    /** Before deleting the user: revoke each stored Apple token. Never throws. */
    public void revokeAll(long userId) {
        List<UserIdentity> apple = identities.findAllByUserId(userId).stream()
                .filter(identity -> identity.getProvider() == SocialProvider.APPLE)
                .toList();
        for (UserIdentity identity : apple) {
            revoke(identity);
        }
    }

    private void revoke(UserIdentity identity) {
        if (identity.getAppleRefreshToken() == null) {
            log.info("User {} has no stored Apple token (signed in before TASK-112.3); nothing to revoke.",
                    identity.getUserId());
            return;
        }
        if (!isEnabled()) {
            log.error("User {} has a stored Apple token but the Apple keys are not set; it was NOT revoked.",
                    identity.getUserId());
            return;
        }
        String refreshToken;
        try {
            refreshToken = cipher.decrypt(identity.getAppleRefreshToken());
        } catch (IllegalStateException e) {
            log.error("Could not decrypt the Apple token of user {} (was APPLE_TOKEN_ENCRYPTION_KEY changed?); "
                    + "it was NOT revoked.", identity.getUserId());
            return;
        }
        for (int attempt = 1; attempt <= REVOKE_TRIES; attempt++) {
            try {
                api.revoke(identity.getAppleClientId(), refreshToken);
                log.info("Revoked the Apple token of user {}.", identity.getUserId());
                return;
            } catch (RuntimeException e) {
                if (attempt == REVOKE_TRIES) {
                    // The subject lets the developer find the Apple account; the token itself is never logged.
                    log.error("Could not revoke the Apple token of user {} (Apple subject {}) after {} tries: {}",
                            identity.getUserId(), identity.getSubject(), REVOKE_TRIES, e.getMessage());
                }
            }
        }
    }
}
