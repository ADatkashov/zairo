package com.zairo.factory.platform;

import com.zairo.factory.auth.FacebookIdentityVerifierPort;
import com.zairo.factory.auth.FacebookIdentityVerifierPort.VerifiedIdentity;
import com.zairo.factory.auth.GoogleIdTokenVerifierPort;
import com.zairo.factory.auth.OtpSenderPort;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Substitutes fakes for the real provider verifiers/SMS sender, the same
 * way {@link TestNotifications} substitutes a capturing fake for the real
 * (logging) email provider. The real adapters (GoogleIdTokenVerifierAdapter,
 * FacebookGraphIdentityVerifier) make live HTTP calls to Google/Facebook —
 * exactly what a test must not depend on (no real credentials exist in
 * CI/dev, see docs/authentication.md's "Provider configuration" section).
 *
 * <p>The fake tokens are self-describing rather than backed by shared
 * mutable state (a {@code Map<token, identity>} some earlier test call
 * populated) specifically so two threads verifying the *same* literal token
 * concurrently (see IdentityApiTests' race test) see identical, stable
 * results with no ordering dependency between tests.
 */
@TestConfiguration(proxyBeanMethods = false)
class TestIdentityProviders {

    static final String INVALID_GOOGLE_TOKEN = "invalid";
    static final String INVALID_FACEBOOK_TOKEN = "invalid";

    /** Encodes a fake, self-describing Google ID token — see this class's own doc comment. */
    static String googleToken(String subject, String email, boolean emailVerified, String name) {
        return "GOOGLE|" + subject + "|" + orEmpty(email) + "|" + emailVerified + "|" + orEmpty(name);
    }

    /** Encodes a fake, self-describing Facebook access token. */
    static String facebookToken(String subject, String email, String name) {
        return "FACEBOOK|" + subject + "|" + orEmpty(email) + "|" + orEmpty(name);
    }

    private static String orEmpty(String value) {
        return value == null ? "" : value;
    }

    @Bean
    @Primary
    GoogleIdTokenVerifierPort testGoogleIdTokenVerifierPort() {
        return idToken -> {
            if (idToken == null) {
                return Optional.empty();
            }
            String[] parts = idToken.split("\\|", -1);
            if (parts.length != 5 || !"GOOGLE".equals(parts[0]) || parts[1].isBlank()) {
                return Optional.empty();
            }
            String email = parts[2].isEmpty() ? null : parts[2];
            boolean emailVerified = Boolean.parseBoolean(parts[3]);
            String name = parts[4].isEmpty() ? null : parts[4];
            return Optional.of(new GoogleIdTokenVerifierPort.VerifiedIdentity(parts[1], email, emailVerified, name));
        };
    }

    @Bean
    @Primary
    FacebookIdentityVerifierPort testFacebookIdentityVerifierPort() {
        return accessToken -> {
            if (accessToken == null) {
                return Optional.empty();
            }
            String[] parts = accessToken.split("\\|", -1);
            if (parts.length != 4 || !"FACEBOOK".equals(parts[0]) || parts[1].isBlank()) {
                return Optional.empty();
            }
            String email = parts[2].isEmpty() ? null : parts[2];
            String name = parts[3].isEmpty() ? null : parts[3];
            return Optional.of(new VerifiedIdentity(parts[1], email, email != null, name));
        };
    }

    @Bean
    @Primary
    OtpSenderPort testOtpSenderPort(CapturedOtps capturedOtps) {
        return (e164Phone, code) -> capturedOtps.byPhone.put(e164Phone, code);
    }

    @Bean
    CapturedOtps capturedOtps() {
        return new CapturedOtps();
    }

    /** A real Spring bean (not a static field) so it resets per test context, not per JVM — see TestNotifications. */
    static class CapturedOtps {
        final Map<String, String> byPhone = new ConcurrentHashMap<>();
    }
}
