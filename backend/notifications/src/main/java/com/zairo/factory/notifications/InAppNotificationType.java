package com.zairo.factory.notifications;

/**
 * Only the customer-facing events user_app's notification feed shows —
 * owner-facing events (new booking received, provider booking cancelled)
 * and subscription/password-reset emails stay email-only; see
 * {@link NotificationService}'s call sites for which methods persist one
 * of these alongside sending the email.
 */
public enum InAppNotificationType {
    BOOKING_CONFIRMED,
    BOOKING_CANCELLED,
    BOOKING_REMINDER,
    PAYMENT_REFUNDED,
    /** A Smart Fill offer for a freed slot -- see smartfill.SmartFillOfferReadyEvent. */
    SMART_FILL_OFFER,
}
