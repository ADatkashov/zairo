package com.zairo.factory.platformadmin;

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
 * Deliberately not a reuse of {@code auth.JwtService} — same shape, but its
 * own signing key ({@code app.jwt.platform-admin-secret}) and its own claim
 * name ({@code platformRole}, not {@code role}). A customer/business access
 * token can never validate here: it's signed with a different key entirely,
 * not merely carrying a role string this module wouldn't recognize. See
 * platform-admin/build.gradle.kts for why this isn't a dependency on the
 * {@code auth} module instead.
 */
@Component
public class PlatformAdminJwtService {

    private static final String ROLE_CLAIM = "platformRole";

    private final Key signingKey;
    private final Duration accessTokenTtl;

    public PlatformAdminJwtService(@Value("${app.jwt.platform-admin-secret}") String secret,
            @Value("${app.jwt.platform-admin-access-token-ttl-minutes:30}") long accessTokenTtlMinutes) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenTtl = Duration.ofMinutes(accessTokenTtlMinutes);
    }

    public String issueAccessToken(UUID adminId, String role) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(adminId.toString())
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
            UUID adminId = UUID.fromString(claims.getSubject());
            String role = claims.get(ROLE_CLAIM, String.class);
            return Optional.of(new AccessTokenClaims(adminId, role));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    public record AccessTokenClaims(UUID adminId, String role) {
    }
}
