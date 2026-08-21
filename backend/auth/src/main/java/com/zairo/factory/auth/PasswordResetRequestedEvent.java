package com.zairo.factory.auth;

import java.util.UUID;

/**
 * Published when a password reset is requested for a real account — see
 * ADR-0002 (in-process domain events instead of Kafka), same pattern as
 * booking's BookingConfirmedEvent/BookingCancelledEvent. Carries the raw
 * reset token (not persisted anywhere — only its hash is, see
 * PasswordResetToken) so a listener can actually deliver it; auth itself
 * doesn't know or care how it gets delivered.
 *
 * <p>Using an event here instead of auth calling notifications directly
 * isn't just for consistency: notifications already needs a Gradle
 * dependency on auth (to build this event type) as well as on booking (for
 * BookingConfirmedEvent/BookingCancelledEvent) — if auth also depended on
 * notifications, that would cycle back (auth -> notifications -> booking ->
 * auth, since booking depends on auth for CurrentUser).
 */
public record PasswordResetRequestedEvent(UUID userId, String email, String resetToken) {
}
