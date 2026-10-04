package com.zairo.factory.auth;

import java.util.Optional;
import java.util.UUID;

/**
 * A module's veto over account deletion -- e.g. booking refuses while the user still has upcoming bookings, providers
 * while they still own a business. {@code auth} sits at the bottom of the module graph and can't ask those modules
 * itself, so each one contributes a bean implementing this and {@link AuthService} collects them all (same
 * one-directional pattern as every cross-module hook here, see ADR-0002).
 */
public interface AccountDeletionGuard {

    /** A human-readable reason shown to the user (becomes the 409 message), or empty if deletion is fine. */
    Optional<String> blockingReason(UUID userId);
}
