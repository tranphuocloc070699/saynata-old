package com.englishtranslation.backend.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** A Google or Apple account that signs in to one of our users. Found again by (provider, subject). */
@Entity
@Table(name = "user_identity")
public class UserIdentity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "provider", nullable = false, length = 20)
    private SocialProvider provider;

    @Column(name = "subject", nullable = false, length = 255)
    private String subject;

    /** The email the provider gave at the first sign-in. Only for the admin to read; sign-in uses the subject. */
    @Column(name = "email", length = 255)
    private String email;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    /** Apple only: the refresh token, encrypted ({@link AppleTokenCipher}); revoked when the account is deleted. */
    @Column(name = "apple_refresh_token")
    private String appleRefreshToken;

    /** Apple only: the bundle ID the token was made for; the revoke call must use the same one. */
    @Column(name = "apple_client_id", length = 255)
    private String appleClientId;

    protected UserIdentity() {
    }

    public UserIdentity(Long userId, SocialProvider provider, String subject, String email, Instant createdAt) {
        this.userId = userId;
        this.provider = provider;
        this.subject = subject;
        this.email = email;
        this.createdAt = createdAt;
    }

    public Long getUserId() {
        return userId;
    }

    public SocialProvider getProvider() {
        return provider;
    }

    public String getSubject() {
        return subject;
    }

    public String getAppleRefreshToken() {
        return appleRefreshToken;
    }

    public String getAppleClientId() {
        return appleClientId;
    }

    /** The newest sign-in's token replaces the older one. */
    public void setAppleRefreshToken(String encryptedToken, String clientId) {
        this.appleRefreshToken = encryptedToken;
        this.appleClientId = clientId;
    }
}
