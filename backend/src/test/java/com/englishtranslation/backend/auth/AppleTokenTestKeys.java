package com.englishtranslation.backend.auth;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.SecureRandom;
import java.security.spec.ECGenParameterSpec;
import java.util.Base64;

/** A made-up "Sign in with Apple" key (.p8, EC P-256) and encryption key for tests. */
final class AppleTokenTestKeys {

    static final KeyPair KEY_PAIR = newKeyPair();
    static final String PRIVATE_KEY_PEM = "-----BEGIN PRIVATE KEY-----\n"
            + Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(KEY_PAIR.getPrivate().getEncoded())
            + "\n-----END PRIVATE KEY-----\n";
    static final String ENCRYPTION_KEY = newEncryptionKey();

    private AppleTokenTestKeys() {
    }

    private static KeyPair newKeyPair() {
        try {
            KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
            generator.initialize(new ECGenParameterSpec("secp256r1"));
            return generator.generateKeyPair();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    static String newEncryptionKey() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        return Base64.getEncoder().encodeToString(bytes);
    }

    static AppleTokenProperties properties(String baseUrl) {
        return new AppleTokenProperties("TEAM123", "KEY456", PRIVATE_KEY_PEM, ENCRYPTION_KEY, baseUrl);
    }

}
