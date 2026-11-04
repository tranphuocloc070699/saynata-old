package com.englishtranslation.backend.auth;

import com.englishtranslation.backend.user.User;
import com.englishtranslation.backend.user.UserRepository;
import java.time.Clock;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/**
 * Sign in with Google or Apple. The app gets an ID token from the provider and sends it here; we check it
 * ({@link IdTokenVerifier}) and hand out the same tokens as the email code.
 * <p>
 * Finding the user: first by the provider account (provider + subject). The first time, by the email the provider
 * confirmed, so a person who signed in with an email code before keeps the same account. The provider account is
 * then remembered, so a later email change at Google or Apple does not make a second account.
 * <p>
 * Apple: when the app also sends the authorization code, {@link AppleTokenService} keeps Apple's refresh token so
 * it can be revoked when the account is deleted (TASK-112.3).
 */
@Service
public class SocialSignInService {

    private final IdTokenVerifier verifier;
    private final UserIdentityRepository identities;
    private final UserRepository users;
    private final AuthService auth;
    private final AppleTokenService appleTokens;
    private final Clock clock;

    public SocialSignInService(IdTokenVerifier verifier, UserIdentityRepository identities, UserRepository users,
            AuthService auth, AppleTokenService appleTokens, Clock clock) {
        this.verifier = verifier;
        this.identities = identities;
        this.users = users;
        this.auth = auth;
        this.appleTokens = appleTokens;
        this.clock = clock;
    }

    /** {@code authorizationCode}: Apple only, may be null (older app builds, Google). */
    public AuthService.TokenResponse signIn(SocialProvider provider, String idToken, String rawNonce,
            String authorizationCode) {
        IdTokenVerifier.VerifiedIdentity identity = verifier.verify(provider, idToken, rawNonce);

        UserIdentity saved = identities.findByProviderAndSubject(provider, identity.subject()).orElse(null);
        User known = saved == null ? null : users.findById(saved.getUserId()).orElse(null);
        if (known != null) {
            appleTokens.rememberSignIn(saved, identity.audience(), authorizationCode);
            return auth.issueTokensFor(known);
        }

        if (identity.email() == null) {
            // Apple sends the email at least on the first sign-in, Google always; without one we cannot make an account.
            throw new InvalidIdTokenException("Your account did not share an email address. Use your email instead.");
        }
        String email = Emails.normalize(identity.email());
        User user = auth.findOrCreateUser(email);
        UserIdentity created;
        try {
            created = identities.saveAndFlush(
                    new UserIdentity(user.getId(), provider, identity.subject(), email, clock.instant()));
        } catch (DataIntegrityViolationException e) {
            // Two first sign-ins at the same moment: the other request saved the same provider account already.
            created = identities.findByProviderAndSubject(provider, identity.subject()).orElse(null);
        }
        appleTokens.rememberSignIn(created, identity.audience(), authorizationCode);
        return auth.issueTokensFor(user);
    }
}
