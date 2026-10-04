package com.zairo.factory.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.sun.net.httpserver.HttpServer;
import io.jsonwebtoken.Jwts;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPublicKey;
import java.util.Base64;
import java.util.Date;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Real RS256 signing + a local JWKS endpoint standing in for appleid.apple.com/auth/keys. */
class AppleIdTokenVerifierAdapterTest {

    private static final String BUNDLE_ID = "kz.zairo.app";
    private static final String ISSUER = "https://appleid.apple.com";

    private HttpServer server;
    private KeyPair signingKey;
    private KeyPair otherKey;
    private AppleIdTokenVerifierAdapter adapter;

    @BeforeEach
    void setUp() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        signingKey = generator.generateKeyPair();
        otherKey = generator.generateKeyPair();

        RSAPublicKey pub = (RSAPublicKey) signingKey.getPublic();
        String jwks = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"k1\",\"use\":\"sig\",\"alg\":\"RS256\","
                + "\"n\":\"" + b64(pub.getModulus().toByteArray()) + "\",\"e\":\"" + b64(pub.getPublicExponent().toByteArray())
                + "\"}]}";
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/keys", exchange -> {
            byte[] out = jwks.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, out.length);
            exchange.getResponseBody().write(out);
            exchange.close();
        });
        server.start();
        adapter = new AppleIdTokenVerifierAdapter(BUNDLE_ID, "http://127.0.0.1:" + server.getAddress().getPort() + "/keys");
    }

    @AfterEach
    void tearDown() {
        server.stop(0);
    }

    private static String b64(byte[] bigEndianWithPossibleSignByte) {
        byte[] bytes = bigEndianWithPossibleSignByte;
        if (bytes.length > 1 && bytes[0] == 0) {
            bytes = java.util.Arrays.copyOfRange(bytes, 1, bytes.length);
        }
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String token(KeyPair key, String kid, String issuer, String audience, long ttlMillis, Object emailVerified) {
        return Jwts.builder().header().keyId(kid).and().issuer(issuer).audience().add(audience).and().subject("apple-user-1")
                .claim("email", "person@privaterelay.appleid.com").claim("email_verified", emailVerified)
                .expiration(new Date(System.currentTimeMillis() + ttlMillis)).signWith(key.getPrivate(), Jwts.SIG.RS256)
                .compact();
    }

    @Test
    void acceptsAValidTokenAndReadsTheClaims() {
        var identity = adapter.verify(token(signingKey, "k1", ISSUER, BUNDLE_ID, 60_000, "true"));

        assertThat(identity).isPresent();
        assertThat(identity.get().subject()).isEqualTo("apple-user-1");
        assertThat(identity.get().email()).isEqualTo("person@privaterelay.appleid.com");
        assertThat(identity.get().emailVerified()).isTrue();
    }

    @Test
    void emailVerifiedMayBeABooleanToo() {
        assertThat(adapter.verify(token(signingKey, "k1", ISSUER, BUNDLE_ID, 60_000, true)).get().emailVerified())
                .isTrue();
        assertThat(adapter.verify(token(signingKey, "k1", ISSUER, BUNDLE_ID, 60_000, false)).get().emailVerified())
                .isFalse();
    }

    @Test
    void rejectsATokenSignedWithAnotherKey() {
        assertThat(adapter.verify(token(otherKey, "k1", ISSUER, BUNDLE_ID, 60_000, "true"))).isEmpty();
    }

    @Test
    void rejectsAnUnknownKeyId() {
        assertThat(adapter.verify(token(signingKey, "nope", ISSUER, BUNDLE_ID, 60_000, "true"))).isEmpty();
    }

    @Test
    void rejectsTheWrongIssuerAudienceOrAnExpiredToken() {
        assertThat(adapter.verify(token(signingKey, "k1", "https://evil.example", BUNDLE_ID, 60_000, "true"))).isEmpty();
        assertThat(adapter.verify(token(signingKey, "k1", ISSUER, "some.other.app", 60_000, "true"))).isEmpty();
        assertThat(adapter.verify(token(signingKey, "k1", ISSUER, BUNDLE_ID, -60_000, "true"))).isEmpty();
    }

    @Test
    void rejectsGarbageAndBlank() {
        assertThat(adapter.verify("not-a-jwt")).isEmpty();
        assertThat(adapter.verify("")).isEmpty();
        assertThat(adapter.verify(null)).isEmpty();
    }
}
