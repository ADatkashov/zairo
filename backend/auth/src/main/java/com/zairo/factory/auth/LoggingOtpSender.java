package com.zairo.factory.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Logs the OTP instead of sending it over SMS — this project has no real
 * SMS provider account/credentials yet, same situation as {@code
 * notifications.LoggingEmailNotificationProvider} for password-reset
 * emails. Not a pretend-success mock: it genuinely delivers to a real sink
 * (the server log), which is enough for local development and CI — a
 * developer/test reads the code straight out of the log instead of
 * receiving a real text message. Replace with a real {@link OtpSenderPort}
 * behind a Spring profile/conditional bean once this project has real SMS
 * provider credentials — nothing else in this module needs to change.
 *
 * <p>Deliberately the one place in this feature allowed to put the code in
 * a log line — this is the delivery channel itself, standing in for a real
 * SMS gateway that would receive the same plaintext code. Nowhere else
 * (AuthAuditLog, exception messages, GlobalExceptionHandler) may do this —
 * see AuthAuditLog's own doc comment.
 */
@Component
class LoggingOtpSender implements OtpSenderPort {

    private static final Logger log = LoggerFactory.getLogger(LoggingOtpSender.class);

    @Override
    public void send(String e164Phone, String code) {
        log.info("SMS to={} body=\"Your ZAIRO code is {}. It expires in a few minutes.\"", e164Phone, code);
    }
}
