package com.englishtranslation.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.nimbusds.jose.crypto.ECDSAVerifier;
import com.nimbusds.jwt.SignedJWT;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.interfaces.ECPublicKey;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.stream.Collectors;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The real Apple client against a fake Apple server on localhost (TASK-112.3). */
class RemoteAppleTokenApiTest {

    private static final Instant NOW = Instant.parse("2026-11-04T10:00:00Z");

    private HttpServer server;
    private final List<String> paths = new CopyOnWriteArrayList<>();
    private final List<Map<String, String>> forms = new CopyOnWriteArrayList<>();
    private volatile int status = 200;
    private volatile String reply = "{\"access_token\":\"a\",\"refresh_token\":\"r-123\",\"id_token\":\"i\"}";

    @BeforeEach
    void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/auth/", exchange -> {
            paths.add(exchange.getRequestURI().getPath());
            forms.add(parse(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8)));
            byte[] bytes = reply.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private RemoteAppleTokenApi api() {
        String url = "http://127.0.0.1:" + server.getAddress().getPort();
        return new RemoteAppleTokenApi(AppleTokenTestKeys.properties(url), Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static Map<String, String> parse(String form) {
        return Arrays.stream(form.split("&")).map(pair -> pair.split("=", 2)).collect(Collectors.toMap(
                p -> URLDecoder.decode(p[0], StandardCharsets.UTF_8),
                p -> URLDecoder.decode(p[1], StandardCharsets.UTF_8)));
    }

    @Test
    void exchangeSendsTheCodeAndReturnsTheRefreshToken() {
        String refresh = api().exchangeCode("com.example.app", "code-1");

        assertThat(refresh).isEqualTo("r-123");
        assertThat(paths).containsExactly("/auth/token");
        assertThat(forms.get(0)).containsEntry("client_id", "com.example.app")
                .containsEntry("code", "code-1")
                .containsEntry("grant_type", "authorization_code")
                .containsKey("client_secret");
    }

    @Test
    void theClientSecretIsAnEs256JwtSignedWithTheAppleKey() throws Exception {
        api().revoke("com.example.app.Mac", "r-9");

        SignedJWT secret = SignedJWT.parse(forms.get(0).get("client_secret"));
        assertThat(secret.verify(new ECDSAVerifier((ECPublicKey) AppleTokenTestKeys.KEY_PAIR.getPublic()))).isTrue();
        assertThat(secret.getHeader().getAlgorithm().getName()).isEqualTo("ES256");
        assertThat(secret.getHeader().getKeyID()).isEqualTo("KEY456");
        assertThat(secret.getJWTClaimsSet().getIssuer()).isEqualTo("TEAM123");
        assertThat(secret.getJWTClaimsSet().getSubject()).isEqualTo("com.example.app.Mac");
        assertThat(secret.getJWTClaimsSet().getAudience()).containsExactly("https://appleid.apple.com");
        assertThat(secret.getJWTClaimsSet().getExpirationTime().toInstant()).isAfter(NOW).isBefore(NOW.plusSeconds(3600));
    }

    @Test
    void revokeSendsTheRefreshToken() {
        api().revoke("com.example.app", "r-9");

        assertThat(paths).containsExactly("/auth/revoke");
        assertThat(forms.get(0)).containsEntry("token", "r-9").containsEntry("token_type_hint", "refresh_token")
                .containsEntry("client_id", "com.example.app");
    }

    @Test
    void anErrorAnswerThrowsWithAppleErrorButNotTheBody() {
        status = 400;
        reply = "{\"error\":\"invalid_grant\",\"secret\":\"do-not-log\"}";

        assertThatThrownBy(() -> api().exchangeCode("com.example.app", "old-code"))
                .isInstanceOf(AppleTokenApi.AppleTokenException.class)
                .hasMessageContaining("400").hasMessageContaining("invalid_grant")
                .hasMessageNotContaining("do-not-log");
        assertThatThrownBy(() -> api().revoke("com.example.app", "r"))
                .isInstanceOf(AppleTokenApi.AppleTokenException.class);
    }

    @Test
    void anAnswerWithoutARefreshTokenThrows() {
        reply = "{\"access_token\":\"a\"}";

        assertThatThrownBy(() -> api().exchangeCode("com.example.app", "c"))
                .isInstanceOf(AppleTokenApi.AppleTokenException.class);
    }

    @Test
    void aPrivateKeyOnOneLineWithWrittenNewlinesIsAccepted() {
        String oneLine = AppleTokenTestKeys.PRIVATE_KEY_PEM.replace("\n", "\\n");

        assertThat(RemoteAppleTokenApi.parsePrivateKey(oneLine).getEncoded())
                .isEqualTo(AppleTokenTestKeys.KEY_PAIR.getPrivate().getEncoded());
        assertThatThrownBy(() -> RemoteAppleTokenApi.parsePrivateKey("not a key"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("APPLE_PRIVATE_KEY");
    }
}
