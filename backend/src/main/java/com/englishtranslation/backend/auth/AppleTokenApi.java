package com.englishtranslation.backend.auth;

/** Apple's token endpoints. The real one is {@link RemoteAppleTokenApi}; tests use a fake. */
public interface AppleTokenApi {

    /** Swaps the sign-in's authorization code for Apple's refresh token. Throws {@link AppleTokenException}. */
    String exchangeCode(String clientId, String authorizationCode);

    /** Revokes the refresh token, which ends the app's Apple sign-in. Throws {@link AppleTokenException}. */
    void revoke(String clientId, String refreshToken);

    class AppleTokenException extends RuntimeException {
        public AppleTokenException(String message) {
            super(message);
        }

        public AppleTokenException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
