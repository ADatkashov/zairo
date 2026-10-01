package com.zairo.factory.auth;

/**
 * Port to an SMS/OTP delivery channel — shaped the same way {@code
 * notifications.EmailNotificationProvider} is: one interface, one real
 * implementation for now ({@link LoggingOtpSender}), swapped for a real SMS
 * provider (Twilio, AWS SNS, a local telco gateway, ...) later without
 * IdentityService or PhoneOtpService needing to change.
 */
public interface OtpSenderPort {

    /** {@code e164Phone} is always already normalized (see PhoneNumberNormalizer) before this is called. */
    void send(String e164Phone, String code);
}
