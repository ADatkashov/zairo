package com.zairo.factory.auth;

import java.util.UUID;

/**
 * Published when a person has just proven a phone number with an SMS code and it became (or already was)
 * an identity of {@code userId} — phone sign-up/sign-in or linking a phone to an account. {@code phone} is
 * the normalized E.164 number. Lets other modules react (e.g. {@code invitations} attaches the person to
 * the businesses that invited this number) without auth depending on them — same in-process-event pattern
 * as {@link PasswordResetRequestedEvent}.
 */
public record PhoneVerifiedEvent(UUID userId, String phone) {
}
