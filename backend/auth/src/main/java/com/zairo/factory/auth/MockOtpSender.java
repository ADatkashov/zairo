package com.zairo.factory.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

/**
 * Pre-production stand-in for a real SMS provider: sends nothing. Active
 * only while {@code app.otp.mock-code} (env {@code OTP_MOCK_CODE}) is set,
 * in which case {@link PhoneOtpService} issues that one fixed code for every
 * phone number instead of a random one — so phone sign-in/registration/reset
 * can be tried end to end without paying for SMS. The app learns about it
 * through {@code GET /auth/phone/sms-mode} and shows the code on screen.
 *
 * <p><b>Not secure</b>: anyone who knows a phone number can sign in to (or
 * reset the password of) that number's account with the fixed code. Remove
 * {@code OTP_MOCK_CODE} before real users arrive; with it unset the real
 * sender ({@link TwilioOtpSender}) takes over and nothing else changes.
 * ProductionSecretsValidator lets a {@code prod}-profile server start with
 * the mock on only to allow a deployed test environment, and logs a loud
 * warning when it does.
 */
@Component
@ConditionalOnExpression("'${app.otp.mock-code:}'.length() > 0")
class MockOtpSender implements OtpSenderPort {

    private static final Logger log = LoggerFactory.getLogger(MockOtpSender.class);

    @Override
    public void send(String e164Phone, String code) {
        log.warn("MOCK SMS - nothing was sent. to={} code={}", e164Phone, code);
    }
}
