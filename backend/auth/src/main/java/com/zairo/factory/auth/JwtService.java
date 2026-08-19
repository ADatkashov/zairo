package com.zairo.factory.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Hand-rolled JWT issuing/validation — see auth/build.gradle.kts for why
 * this isn't spring-boot-starter-security. Access tokens are short-lived
 * and stateless (no DB lookup to validate); refresh tokens are opaque
 * random values checked against RefreshTokenRepository (see RefreshToken).
 */
@Component
public class JwtService {

    private static final String ROLE_CLAIM = "role";

    private final Key signingKey;
    private final Duration accessTokenTtl;

    public JwtService(@Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.access-token-ttl-minutes:30}") long accessTokenTtlMinutes) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenTtl = Duration.ofMinutes(accessTokenTtlMinutes);
    }

    public String issueAccessToken(UUID userId, String role) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .claim(ROLE_CLAIM, role)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTokenTtl)))
                .signWith(signingKey)
                .compact();
    }

    public Optional<AccessTokenClaims> validateAccessToken(String token) {
        try {
            Claims claims = Jwts.parser().verifyWith((javax.crypto.SecretKey) signingKey).build()
                    .parseSignedClaims(token).getPayload();
            UUID userId = UUID.fromString(claims.getSubject());
            String role = claims.get(ROLE_CLAIM, String.class);
            return Optional.of(new AccessTokenClaims(userId, role));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    public record AccessTokenClaims(UUID userId, String role) {
    }
}
