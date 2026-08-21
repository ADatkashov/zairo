package com.zairo.factory.platform;

import com.zairo.factory.notifications.EmailNotificationProvider;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Substitutes a capturing fake for the real (logging) EmailNotificationProvider
 * so tests can read exactly what a real email provider's recipient would
 * have gotten, without parsing log output. Shared across *ApiTests classes
 * that need to observe a notification (auth's password reset, booking's
 * confirmation/cancellation emails) — same "shared test-support helper"
 * convention as TestAuth.
 */
@TestConfiguration(proxyBeanMethods = false)
class TestNotifications {

    @Bean
    @Primary
    EmailNotificationProvider testEmailNotificationProvider(CapturedEmails capturedEmails) {
        return (toEmail, subject, body) -> capturedEmails.sent.add(new CapturedEmail(toEmail, subject, body));
    }

    @Bean
    CapturedEmails capturedEmails() {
        return new CapturedEmails();
    }

    record CapturedEmail(String toEmail, String subject, String body) {
    }

    /** A real Spring bean (not a static field) so it resets per test context, not per JVM. */
    static class CapturedEmails {
        final List<CapturedEmail> sent = new CopyOnWriteArrayList<>();
    }
}
