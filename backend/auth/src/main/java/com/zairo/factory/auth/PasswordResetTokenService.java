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
import org.springframework.transaction.annotation.Transactional;

/**
 * Same hashing/expiry/single-use shape as {@link RefreshTokenService}, at a
 * much shorter TTL — a reset code is meant to be used within minutes, not
 * carried around for weeks like a refresh token.
 */
@Component
class PasswordResetTokenService {

    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final Duration tokenTtl;
    private final SecureRandom secureRandom = new SecureRandom();

    PasswordResetTokenService(PasswordResetTokenRepository passwordResetTokenRepository,
            @Value("${app.auth.password-reset-token-ttl-minutes:60}") long tokenTtlMinutes) {
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.tokenTtl = Duration.ofMinutes(tokenTtlMinutes);
    }

    /**
     * Returns the raw token to email to the user — only its hash is
     * persisted. Any previous still-valid token for this user is dropped
     * first, so requesting a new code invalidates an older, unused one
     * rather than leaving two live at once.
     */
    /** Account deletion: drops any outstanding reset code. Runs inside the caller's transaction. */
    void deleteAllForUser(UUID userId) {
        passwordResetTokenRepository.deleteByUserId(userId);
    }

    @Transactional
    String issue(UUID userId) {
        passwordResetTokenRepository.deleteByUserId(userId);

        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);

        PasswordResetToken token = new PasswordResetToken(UUID.randomUUID(), userId, hash(rawToken),
                Instant.now().plus(tokenTtl), Instant.now());
        passwordResetTokenRepository.save(token);
        return rawToken;
    }

    /**
     * Validates the token and deletes it — a consumed (or expired) token
     * can never be used again, matching {@link RefreshTokenService#rotate}'s
     * delete-on-use pattern.
     */
    @Transactional
    UUID consume(String rawToken) {
        PasswordResetToken existing = passwordResetTokenRepository.findByTokenHash(hash(rawToken))
                .filter(t -> t.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InvalidPasswordResetTokenException("Reset token is invalid or expired"));

        passwordResetTokenRepository.delete(existing);
        return existing.getUserId();
    }

    private static String hash(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}
