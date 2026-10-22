package com.zairo.factory.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import java.math.BigInteger;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Real "Sign in with Apple" identity-token verification. Unlike Google,
 * Apple has no token-introspection endpoint: the standard way (Apple's own
 * docs) is to verify the RS256 JWT signature against Apple's published key
 * set ({@code https://appleid.apple.com/auth/keys}). jjwt (already a
 * dependency for ZAIRO's own tokens) does the signature, expiry and issuer
 * checks — no hand-rolled cryptography; this class only turns Apple's JWK
 * (n, e) into a {@link PublicKey} and checks the audience.
 *
 * <ul>
 *   <li><b>Signature / expiration</b> — jjwt, RS256 only, against the key
 *       whose {@code kid} the token names (keys cached for an hour; one
 *       forced refresh if a {@code kid} is unknown, to survive key rotation).
 *   <li><b>Issuer</b> — must be {@code https://appleid.apple.com}.
 *   <li><b>Audience</b> — must be one of {@code app.oauth.apple.client-ids}
 *       (the iOS bundle id, plus a Services ID if Android/web is added).
 *       Left blank, no audience is enforced — never true in production, see
 *       ProductionSecretsValidator.
 * </ul>
 *
 * <p>Every failure collapses to an empty {@link Optional}.
 */
@Component
class AppleIdTokenVerifierAdapter implements AppleIdTokenVerifierPort {

    private static final Logger log = LoggerFactory.getLogger(AppleIdTokenVerifierAdapter.class);
    private static final String ISSUER = "https://appleid.apple.com";
    private static final Duration KEYS_TTL = Duration.ofHours(1);

    private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final List<String> audiences;
    private final String keysUrl;
    private final boolean enabled;

    private volatile Map<String, PublicKey> keysById = Map.of();
    private volatile Instant keysFetchedAt = Instant.EPOCH;

    AppleIdTokenVerifierAdapter(@Value("${app.oauth.apple.client-ids:}") String clientIdsCsv,
            @Value("${app.oauth.apple.keys-url:https://appleid.apple.com/auth/keys}") String keysUrl,
            @Value("${app.oauth.apple.enabled:true}") boolean enabled) {
        this.enabled = enabled;
        this.audiences = Arrays.stream(clientIdsCsv.split(",")).map(String::trim).filter(id -> !id.isEmpty()).toList();
        this.keysUrl = keysUrl;
    }

    @Override
    public Optional<VerifiedIdentity> verify(String identityToken) {
        // Switched off (app.oauth.apple.enabled=false): see GoogleIdTokenVerifierAdapter.
        if (!enabled || identityToken == null || identityToken.isBlank()) {
            return Optional.empty();
        }
        try {
            Jws<Claims> jws = Jwts.parser()
                    .keyLocator(header -> {
                        Object kid = header.get("kid");
                        return kid == null ? null : keyFor(kid.toString());
                    })
                    .requireIssuer(ISSUER)
                    .build()
                    .parseSignedClaims(identityToken);
            if (!"RS256".equals(jws.getHeader().getAlgorithm())) {
                return Optional.empty();
            }
            Claims claims = jws.getPayload();
            if (!audiences.isEmpty() && (claims.getAudience() == null
                    || claims.getAudience().stream().noneMatch(audiences::contains))) {
                return Optional.empty();
            }
            String subject = claims.getSubject();
            if (subject == null || subject.isBlank()) {
                return Optional.empty();
            }
            Object emailClaim = claims.get("email");
            String email = emailClaim == null ? null : emailClaim.toString();
            // Apple sends email_verified as either the string "true" or a boolean.
            boolean emailVerified = email != null && "true".equalsIgnoreCase(String.valueOf(claims.get("email_verified")));
            return Optional.of(new VerifiedIdentity(subject, email, emailVerified));
        } catch (RuntimeException e) {
            // Bad signature, expired, wrong issuer, malformed, unknown kid ... — all just "not verified".
            log.debug("Apple identity token rejected: {}", e.getMessage());
            return Optional.empty();
        }
    }

    private PublicKey keyFor(String kid) {
        PublicKey key = keysById.get(kid);
        boolean stale = Instant.now().isAfter(keysFetchedAt.plus(KEYS_TTL));
        if (key == null || stale) {
            refreshKeys();
            key = keysById.get(kid);
        }
        return key;
    }

    private synchronized void refreshKeys() {
        // Don't hammer Apple if tokens keep arriving with unknown key ids.
        if (Instant.now().isBefore(keysFetchedAt.plusSeconds(30))) {
            return;
        }
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(keysUrl)).timeout(Duration.ofSeconds(10)).GET().build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            keysFetchedAt = Instant.now();
            if (response.statusCode() != 200) {
                return;
            }
            Map<String, PublicKey> parsed = new HashMap<>();
            KeyFactory factory = KeyFactory.getInstance("RSA");
            for (JsonNode jwk : objectMapper.readTree(response.body()).path("keys")) {
                if (!"RSA".equals(jwk.path("kty").asText())) {
                    continue;
                }
                BigInteger modulus = new BigInteger(1, Base64.getUrlDecoder().decode(jwk.path("n").asText()));
                BigInteger exponent = new BigInteger(1, Base64.getUrlDecoder().decode(jwk.path("e").asText()));
                parsed.put(jwk.path("kid").asText(), factory.generatePublic(new RSAPublicKeySpec(modulus, exponent)));
            }
            if (!parsed.isEmpty()) {
                keysById = Map.copyOf(parsed);
            }
        } catch (Exception e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            log.warn("Could not refresh Apple signing keys: {}", e.getMessage());
        }
    }
}
