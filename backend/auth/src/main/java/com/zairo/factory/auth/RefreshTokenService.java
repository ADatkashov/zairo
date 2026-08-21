package com.zairo.factory.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
class RefreshTokenService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final Duration refreshTokenTtl;
    private final SecureRandom secureRandom = new SecureRandom();

    RefreshTokenService(RefreshTokenRepository refreshTokenRepository,
            @Value("${app.jwt.refresh-token-ttl-days:30}") long refreshTokenTtlDays) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.refreshTokenTtl = Duration.ofDays(refreshTokenTtlDays);
    }

    /**
     * Returns the raw token to hand to the client — only its hash is
     * persisted (see RefreshToken).
     */
    String issue(UUID userId) {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);

        RefreshToken token = new RefreshToken(UUID.randomUUID(), userId, hash(rawToken),
                Instant.now().plus(refreshTokenTtl), Instant.now());
        refreshTokenRepository.save(token);
        return rawToken;
    }

    /**
     * Validates and rotates: the old token is deleted and a new one issued
     * in the same call, so a refresh token can only be used once.
     */
    RotatedToken rotate(String rawToken) {
        RefreshToken existing = refreshTokenRepository.findByTokenHash(hash(rawToken))
                .filter(t -> t.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InvalidRefreshTokenException("Refresh token is invalid or expired"));

        refreshTokenRepository.delete(existing);
        String newRawToken = issue(existing.getUserId());
        return new RotatedToken(existing.getUserId(), newRawToken);
    }

    /**
     * Called after a password reset: an account whose password just changed
     * (e.g. because it was compromised) shouldn't leave old sessions valid
     * on other devices. Not separately {@code @Transactional} — same as
     * {@link #issue}/{@link #rotate}, it relies on running inside the
     * caller's own transaction (AuthService.resetPassword).
     */
    void revokeAllForUser(UUID userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }

    private static String hash(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    record RotatedToken(UUID userId, String rawToken) {
    }
}
