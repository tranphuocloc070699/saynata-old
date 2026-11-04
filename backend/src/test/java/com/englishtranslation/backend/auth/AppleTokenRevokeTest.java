package com.englishtranslation.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.limits.RateLimiter;
import com.englishtranslation.backend.user.UserRepository;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.json.JsonMapper;

/**
 * Sign in with Apple stores Apple's refresh token, and deleting the account revokes it (TASK-112.3). Apple is a
 * fake that records the calls; {@link RemoteAppleTokenApiTest} tests the real client against a fake server.
 */
@SpringBootTest(properties = { "app.claude.api-key=test-key", "app.auth.social.google-client-ids=test-google-ios",
        "app.auth.social.apple-client-ids=com.example.app" })
@AutoConfigureMockMvc
class AppleTokenRevokeTest {

    @DynamicPropertySource
    static void appleKeys(DynamicPropertyRegistry registry) {
        registry.add("app.auth.apple-tokens.team-id", () -> "TEAM123");
        registry.add("app.auth.apple-tokens.key-id", () -> "KEY456");
        registry.add("app.auth.apple-tokens.private-key", () -> AppleTokenTestKeys.PRIVATE_KEY_PEM);
        registry.add("app.auth.apple-tokens.encryption-key", () -> AppleTokenTestKeys.ENCRYPTION_KEY);
        registry.add("app.auth.apple-tokens.base-url", () -> "http://127.0.0.1:9");
    }

    /** Records every call; {@code failExchange} / {@code failRevoke} make Apple answer with an error. */
    static class FakeApple implements AppleTokenApi {
        final List<String> exchanges = new CopyOnWriteArrayList<>();
        final List<String> revokes = new CopyOnWriteArrayList<>();
        volatile boolean failExchange;
        volatile boolean failRevoke;

        @Override
        public String exchangeCode(String clientId, String authorizationCode) {
            exchanges.add(clientId + " " + authorizationCode);
            if (failExchange) {
                throw new AppleTokenException("Apple /auth/token answered 400: invalid_grant");
            }
            return "refresh-for-" + authorizationCode;
        }

        @Override
        public void revoke(String clientId, String refreshToken) {
            revokes.add(clientId + " " + refreshToken);
            if (failRevoke) {
                throw new AppleTokenException("Could not reach Apple (auth/revoke)");
            }
        }

        void reset() {
            exchanges.clear();
            revokes.clear();
            failExchange = false;
            failRevoke = false;
        }
    }

    @TestConfiguration
    static class Fakes {
        @Bean
        @Primary
        IdTokenKeys fakeIdTokenKeys() {
            return provider -> new ImmutableJWKSet<>(new JWKSet(SocialSignInTest.PROVIDER_KEY.toPublicJWK()));
        }

        @Bean
        @Primary
        FakeApple fakeApple() {
            return new FakeApple();
        }
    }

    @Autowired
    MockMvc mockMvc;
    @Autowired
    FakeApple apple;
    @Autowired
    UserRepository users;
    @Autowired
    UserIdentityRepository identities;
    @Autowired
    RefreshTokenRepository refreshTokens;
    @Autowired
    RateLimiter rateLimiter;
    @Autowired
    AppleTokenService appleTokens;
    @Autowired
    JsonMapper json;

    @MockitoBean
    EmailSender emailSender;
    @MockitoBean
    ClaudeService claude;

    @BeforeEach
    void clean() {
        refreshTokens.deleteAll();
        identities.deleteAll();
        users.deleteAll();
        rateLimiter.reset();
        apple.reset();
    }

    private String signIn(String provider, String idToken, String code) throws Exception {
        Map<String, String> body = new HashMap<>(Map.of("idToken", idToken, "nonce", SocialSignInTest.NONCE));
        if (code != null) {
            body.put("authorizationCode", code);
        }
        String answer = mockMvc.perform(post("/api/auth/" + provider).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(body)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(answer).get("accessToken").asString();
    }

    private void deleteAccount(String access) throws Exception {
        mockMvc.perform(delete("/api/me").header("Authorization", "Bearer " + access))
                .andExpect(status().isNoContent());
    }

    private UserIdentity onlyIdentity() {
        assertThat(identities.findAll()).hasSize(1);
        return identities.findAll().get(0);
    }

    @Test
    void theKeysAreSetSoTheServiceIsOn() {
        assertThat(appleTokens.isEnabled()).isTrue();
    }

    @Test
    void appleSignInWithACodeStoresTheRefreshTokenEncrypted() throws Exception {
        signIn("apple", SocialSignInTest.appleToken("a-1", "a@icloud.com", c -> { }), "code-1");

        assertThat(apple.exchanges).containsExactly("com.example.app code-1");
        UserIdentity identity = onlyIdentity();
        assertThat(identity.getAppleClientId()).isEqualTo("com.example.app");
        assertThat(identity.getAppleRefreshToken()).isNotBlank().doesNotContain("refresh-for-code-1");
        assertThat(new AppleTokenCipher(AppleTokenTestKeys.ENCRYPTION_KEY).decrypt(identity.getAppleRefreshToken()))
                .isEqualTo("refresh-for-code-1");
    }

    @Test
    void aLaterSignInReplacesTheStoredToken() throws Exception {
        signIn("apple", SocialSignInTest.appleToken("a-1", "a@icloud.com", c -> { }), "code-1");
        signIn("apple", SocialSignInTest.appleToken("a-1", null, c -> { }), "code-2");

        assertThat(new AppleTokenCipher(AppleTokenTestKeys.ENCRYPTION_KEY).decrypt(onlyIdentity().getAppleRefreshToken()))
                .isEqualTo("refresh-for-code-2");
    }

    @Test
    void aFailedExchangeStillSignsIn() throws Exception {
        apple.failExchange = true;

        String access = signIn("apple", SocialSignInTest.appleToken("a-1", "a@icloud.com", c -> { }), "bad-code");

        assertThat(access).isNotBlank();
        assertThat(onlyIdentity().getAppleRefreshToken()).isNull();
    }

    @Test
    void googleSignInNeverCallsApple() throws Exception {
        signIn("google", SocialSignInTest.googleToken("g-1", "g@gmail.com", c -> { }), "ignored");

        assertThat(apple.exchanges).isEmpty();
        assertThat(onlyIdentity().getAppleRefreshToken()).isNull();
    }

    @Test
    void deletingTheAccountRevokesTheAppleTokenFirst() throws Exception {
        String access = signIn("apple", SocialSignInTest.appleToken("a-1", "a@icloud.com", c -> { }), "code-1");

        deleteAccount(access);

        assertThat(apple.revokes).containsExactly("com.example.app refresh-for-code-1");
        assertThat(users.count()).isZero();
        assertThat(identities.count()).isZero();
    }

    @Test
    void aFailedRevokeIsTriedTwiceAndTheAccountIsStillDeleted() throws Exception {
        String access = signIn("apple", SocialSignInTest.appleToken("a-1", "a@icloud.com", c -> { }), "code-1");
        apple.failRevoke = true;

        deleteAccount(access);

        assertThat(apple.revokes).hasSize(AppleTokenService.REVOKE_TRIES);
        assertThat(users.count()).isZero();
    }

    @Test
    void anAccountWithoutAStoredTokenIsDeletedWithoutCallingApple() throws Exception {
        String access = signIn("apple", SocialSignInTest.appleToken("a-1", "a@icloud.com", c -> { }), null);

        deleteAccount(access);

        assertThat(apple.exchanges).isEmpty();
        assertThat(apple.revokes).isEmpty();
        assertThat(users.count()).isZero();
    }
}
