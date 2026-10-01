package com.zairo.factory.auth;

import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Structured, security-relevant auth events — see CLAUDE.md task spec §25.
 * This codebase has no dedicated analytics/event-store module for
 * end-user activity (the one audit-log table that exists,
 * {@code platformadmin.PlatformAuditLogService}, is scoped to platform-admin
 * moderation actions, not customer auth); a structured log line is the
 * existing, lightweight mechanism the rest of the codebase already relies
 * on for this kind of thing (e.g. GlobalExceptionHandler's own
 * {@code log.error} on unexpected failures). Adding a whole new
 * event-store table for this would be exactly the kind of unrequested
 * infrastructure CLAUDE.md's task spec §26 says not to build.
 *
 * <p><b>Never</b> log an OTP code, access token, refresh token, OAuth
 * credential, or raw provider response here — every method below takes
 * only identifiers (user id, provider, phone-not-logged) and outcomes, on
 * purpose. Compare {@link LoggingOtpSender}, which is a delivery channel
 * standing in for a real SMS gateway and therefore does log the code —
 * this class is not that.
 */
@Component
class AuthAuditLog {

    private static final Logger log = LoggerFactory.getLogger("com.zairo.factory.auth.AUDIT");

    void loginSucceeded(UUID userId, String method) {
        log.info("auth.login.success userId={} method={}", userId, method);
    }

    void loginFailed(String method, String reason) {
        log.info("auth.login.failure method={} reason={}", method, reason);
    }

    void otpRequested() {
        log.info("auth.otp.requested");
    }

    void otpVerificationFailed(String reason) {
        log.info("auth.otp.verify_failed reason={}", reason);
    }

    void identityLinked(UUID userId, IdentityProvider provider) {
        log.info("auth.identity.linked userId={} provider={}", userId, provider);
    }

    void biometricToggled(UUID userId, boolean enabled) {
        log.info("auth.biometric.{} userId={}", enabled ? "enabled" : "disabled", userId);
    }
}
