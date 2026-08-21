package com.zairo.factory.notifications;

/**
 * Port to an email delivery channel (SMTP, SendGrid, SES, etc.) — shaped
 * the same way {@code payments.PaymentProvider} is: one interface, one
 * real implementation for now ({@link LoggingEmailNotificationProvider}),
 * swapped for a real provider later without any caller needing to change.
 */
public interface EmailNotificationProvider {

    void send(String toEmail, String subject, String body);
}
