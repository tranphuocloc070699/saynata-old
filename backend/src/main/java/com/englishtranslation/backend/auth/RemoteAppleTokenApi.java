package com.englishtranslation.backend.auth;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.interfaces.ECPrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Calls https://appleid.apple.com/auth/token and /auth/revoke. Both need a client secret: a short ES256 JWT
 * signed with our "Sign in with Apple" key (iss = team ID, sub = the app's bundle ID, aud = Apple).
 * Apple's docs: "Generate and validate tokens" and "Revoke tokens".
 */
public class RemoteAppleTokenApi implements AppleTokenApi {

    static final String APPLE_AUDIENCE = "https://appleid.apple.com";
    private static final Duration TIMEOUT = Duration.ofSeconds(10);
    private static final Duration SECRET_LIFETIME = Duration.ofMinutes(5);

    private final String teamId;
    private final String keyId;
    private final ECPrivateKey privateKey;
    private final URI baseUrl;
    private final Clock clock;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(TIMEOUT).build();
    private final JsonMapper json = JsonMapper.builder().build();

    public RemoteAppleTokenApi(AppleTokenProperties properties, Clock clock) {
        this.teamId = properties.teamId().trim();
        this.keyId = properties.keyId().trim();
        this.privateKey = parsePrivateKey(properties.privateKey());
        String base = properties.baseUrl() == null || properties.baseUrl().isBlank()
                ? APPLE_AUDIENCE : properties.baseUrl().trim();
        this.baseUrl = URI.create(base.endsWith("/") ? base : base + "/");
        this.clock = clock;
    }

    @Override
    public String exchangeCode(String clientId, String authorizationCode) {
        Map<String, String> form = new LinkedHashMap<>();
        form.put("client_id", clientId);
        form.put("client_secret", clientSecret(clientId));
        form.put("code", authorizationCode);
        form.put("grant_type", "authorization_code");
        HttpResponse<String> response = post("auth/token", form);
        if (response.statusCode() != 200) {
            throw new AppleTokenException("Apple /auth/token answered " + response.statusCode() + ": "
                    + errorOf(response.body()));
        }
        try {
            JsonNode body = json.readTree(response.body());
            JsonNode refresh = body.get("refresh_token");
            if (refresh == null || refresh.asString().isBlank()) {
                throw new AppleTokenException("Apple /auth/token gave no refresh_token");
            }
            return refresh.asString();
        } catch (RuntimeException e) {
            if (e instanceof AppleTokenException ate) {
                throw ate;
            }
            throw new AppleTokenException("Apple /auth/token gave an answer we cannot read", e);
        }
    }

    @Override
    public void revoke(String clientId, String refreshToken) {
        Map<String, String> form = new LinkedHashMap<>();
        form.put("client_id", clientId);
        form.put("client_secret", clientSecret(clientId));
        form.put("token", refreshToken);
        form.put("token_type_hint", "refresh_token");
        HttpResponse<String> response = post("auth/revoke", form);
        if (response.statusCode() != 200) {
            throw new AppleTokenException("Apple /auth/revoke answered " + response.statusCode() + ": "
                    + errorOf(response.body()));
        }
    }

    /** The client secret for this bundle ID. Made per call; it is cheap and lives 5 minutes. */
    String clientSecret(String clientId) {
        Instant now = clock.instant();
        JWTClaimsSet claims = new JWTClaimsSet.Builder()
                .issuer(teamId)
                .subject(clientId)
                .audience(APPLE_AUDIENCE)
                .issueTime(Date.from(now))
                .expirationTime(Date.from(now.plus(SECRET_LIFETIME)))
                .build();
        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.ES256).keyID(keyId).build(), claims);
        try {
            jwt.sign(new ECDSASigner(privateKey));
        } catch (JOSEException e) {
            throw new AppleTokenException("Could not sign the Apple client secret", e);
        }
        return jwt.serialize();
    }

    private HttpResponse<String> post(String path, Map<String, String> form) {
        String body = form.entrySet().stream()
                .map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8) + "="
                        + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
                .collect(Collectors.joining("&"));
        HttpRequest request = HttpRequest.newBuilder(baseUrl.resolve(path))
                .timeout(TIMEOUT)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();
        try {
            return http.send(request, HttpResponse.BodyHandlers.ofString());
        } catch (IOException e) {
            throw new AppleTokenException("Could not reach Apple (" + path + ")", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new AppleTokenException("Interrupted while calling Apple (" + path + ")", e);
        }
    }

    /** Apple's "error" field ("invalid_grant", "invalid_client"...). Never the whole body: it could hold tokens. */
    private String errorOf(String body) {
        try {
            JsonNode error = json.readTree(body).get("error");
            return error == null ? "no error field" : error.asString();
        } catch (RuntimeException e) {
            return "no JSON body";
        }
    }

    /** The .p8 file: PKCS#8, EC P-256. Accepts real newlines or "\n" written out (one-line env values). */
    static ECPrivateKey parsePrivateKey(String pem) {
        String base64 = pem.replace("\\n", "\n")
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
        try {
            byte[] der = Base64.getDecoder().decode(base64);
            return (ECPrivateKey) KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(der));
        } catch (IllegalArgumentException | GeneralSecurityException | ClassCastException e) {
            throw new IllegalStateException("APPLE_PRIVATE_KEY is not a valid .p8 key (PKCS#8, EC P-256).", e);
        }
    }
}
