package com.zairo.factory.notifications;

import org.springframework.stereotype.Service;

/**
 * Entry point other modules call to send a notification — callers never
 * touch {@link EmailNotificationProvider} (or, once they exist, a push/SMS
 * provider) directly. Right now this only covers the one real, direct
 * caller that exists (auth's password-reset email); booking confirmation/
 * cancellation notifications are the next real consumer and will listen
 * for booking's domain events the same way payments' refund-on-cancel
 * listener already does (see BookingCancelledPaymentListener) rather than
 * booking calling this module directly.
 */
@Service
public class NotificationService {

    private final EmailNotificationProvider emailProvider;

    public NotificationService(EmailNotificationProvider emailProvider) {
        this.emailProvider = emailProvider;
    }

    public void sendPasswordResetEmail(String toEmail, String resetToken) {
        String subject = "Reset your Factory password";
        String body = "Use this code to reset your password: " + resetToken
                + "\n\nThis code expires in an hour. If you didn't request a password reset, "
                + "you can safely ignore this email.";
        emailProvider.send(toEmail, subject, body);
    }
}
