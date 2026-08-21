package com.zairo.factory.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Logs the email instead of sending it over SMTP — this project has no real
 * mail provider account/credentials yet. Not a pretend-success mock like
 * {@code payments.MockPaymentProvider}: it genuinely delivers the message
 * to a real sink (the server log), useful as-is for local development and
 * testing (a developer can read a password-reset code straight from the
 * log). Replace with a real {@link EmailNotificationProvider} (JavaMailSender,
 * SendGrid, SES, etc.) behind a Spring profile/conditional bean once this
 * project has real credentials — nothing else in this module, or any
 * caller, needs to change.
 */
@Component
class LoggingEmailNotificationProvider implements EmailNotificationProvider {

    private static final Logger log = LoggerFactory.getLogger(LoggingEmailNotificationProvider.class);

    @Override
    public void send(String toEmail, String subject, String body) {
        log.info("EMAIL to={} subject=\"{}\"\n{}", toEmail, subject, body);
    }
}
