package com.zairo.factory.platform;

import jakarta.annotation.PostConstruct;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Component;

/**
 * Fails application startup fast if it's about to run in production
 * ({@code spring.profiles.active} includes {@code prod}, e.g. {@code
 * SPRING_PROFILES_ACTIVE=prod}) while still using one of the dev-only
 * default secrets committed in {@code application.yml} (Phase 0
 * stabilization).
 *
 * <p>This codebase deliberately has no per-environment config files (see
 * {@code docs/ci-cd.md}'s deployment runbook) — every secret is a single
 * {@code ${ENV_VAR:dev-default}} placeholder, and a real deployment sets
 * the env var. Nothing previously enforced that: forgetting to set {@code
 * JWT_SECRET} (or any of the others below) meant production would silently
 * boot and serve real traffic on a value that's been public in this
 * repository's git history since early in the project. This class doesn't
 * change what the defaults are or how they're read (every existing bean
 * still resolves them exactly as before) — it just refuses to let the
 * application start with them <em>while a deployer has explicitly said
 * this is production</em>, by activating the {@code prod} profile. Nobody
 * has to change how local dev or {@code test} profile runs: neither sets
 * {@code spring.profiles.active=prod}, so this check never even runs for
 * them (see {@link #run}'s own guard).
 */
@Component
class ProductionSecretsValidator {

    // The exact dev-default values committed in application.yml -- kept
    // here, not derived, so a future edit to one default can't silently
    // defeat this check by making "the default" and "the configured value"
    // match by coincidence instead of by the deployer actually overriding
    // anything.
    static final String DEV_JWT_SECRET = "Jc65IChbJdrOLj/C4rT+OCdPEdvzosIIpIG0xYM9dJ1Eflr/QDsOg+hLKOdX8k1B";
    static final String DEV_PLATFORM_ADMIN_JWT_SECRET = "R2v8QnZmU4hLxE0pTsYkD9bWcAoFj3GiN6uHrMz1XqCvS7eKtY5wPd2LbNhOaIu";
    static final String DEV_DB_PASSWORD = "app_factory";
    static final String DEV_STORAGE_SECRET_KEY = "app_factory_secret";

    private static final Logger log = LoggerFactory.getLogger(ProductionSecretsValidator.class);

    private final Environment environment;
    private final String jwtSecret;
    private final String platformAdminJwtSecret;
    private final String dbPassword;
    private final String storageSecretKey;
    private final String googleClientIds;
    private final String appleClientIds;
    private final String twilioAccountSid;
    private final String twilioAuthToken;
    private final String twilioFrom;
    private final String twilioMessagingServiceSid;
    private final String otpMockCode;
    private final boolean googleEnabled;
    private final boolean appleEnabled;

    ProductionSecretsValidator(Environment environment, @Value("${app.jwt.secret}") String jwtSecret,
            @Value("${app.jwt.platform-admin-secret}") String platformAdminJwtSecret,
            @Value("${spring.datasource.password}") String dbPassword,
            @Value("${app.storage.secret-key}") String storageSecretKey,
            @Value("${app.oauth.google.client-ids:}") String googleClientIds,
            @Value("${app.oauth.apple.client-ids:}") String appleClientIds,
            @Value("${app.sms.twilio.account-sid:}") String twilioAccountSid,
            @Value("${app.sms.twilio.auth-token:}") String twilioAuthToken,
            @Value("${app.sms.twilio.from:}") String twilioFrom,
            @Value("${app.sms.twilio.messaging-service-sid:}") String twilioMessagingServiceSid,
            @Value("${app.otp.mock-code:}") String otpMockCode,
            @Value("${app.oauth.google.enabled:true}") boolean googleEnabled,
            @Value("${app.oauth.apple.enabled:true}") boolean appleEnabled) {
        this.googleEnabled = googleEnabled;
        this.appleEnabled = appleEnabled;
        this.environment = environment;
        this.jwtSecret = jwtSecret;
        this.platformAdminJwtSecret = platformAdminJwtSecret;
        this.dbPassword = dbPassword;
        this.storageSecretKey = storageSecretKey;
        this.googleClientIds = googleClientIds;
        this.appleClientIds = appleClientIds;
        this.twilioAccountSid = twilioAccountSid;
        this.twilioAuthToken = twilioAuthToken;
        this.twilioFrom = twilioFrom;
        this.twilioMessagingServiceSid = twilioMessagingServiceSid;
        this.otpMockCode = otpMockCode;
    }

    @PostConstruct
    void run() {
        if (!environment.acceptsProfiles(Profiles.of("prod"))) {
            return;
        }
        List<String> problems = new ArrayList<>();
        checkOverridden(problems, "JWT_SECRET (app.jwt.secret)", jwtSecret, DEV_JWT_SECRET);
        checkOverridden(problems, "PLATFORM_ADMIN_JWT_SECRET (app.jwt.platform-admin-secret)", platformAdminJwtSecret,
                DEV_PLATFORM_ADMIN_JWT_SECRET);
        checkOverridden(problems, "DB_PASSWORD (spring.datasource.password)", dbPassword, DEV_DB_PASSWORD);
        checkOverridden(problems, "MINIO_SECRET_KEY (app.storage.secret-key)", storageSecretKey,
                DEV_STORAGE_SECRET_KEY);
        // No dev-default to compare against for these — they simply must
        // not be blank in production. Blank Google client ids would make
        // GoogleIdTokenVerifierAdapter accept a Google ID token issued to
        // *any* app (no audience check at all). Facebook login is not
        // offered any more, so its credentials are no longer required
        // (FacebookGraphIdentityVerifier just rejects every token when blank).
        // A provider switched off (GOOGLE_OAUTH_ENABLED / APPLE_OAUTH_ENABLED = false) needs no client ids:
        // its verifier rejects every token. Switched on, the ids stay mandatory.
        if (googleEnabled) {
            checkNotBlank(problems, "GOOGLE_OAUTH_CLIENT_IDS (app.oauth.google.client-ids)", googleClientIds);
        }
        // Same security hole as blank Google ids: with no audience configured,
        // an Apple identity token issued to *any* app would be accepted.
        if (appleEnabled) {
            checkNotBlank(problems, "APPLE_CLIENT_IDS (app.oauth.apple.client-ids)", appleClientIds);
        }
        boolean smsMocked = otpMockCode != null && !otpMockCode.isBlank();
        if (smsMocked) {
            // Allowed on purpose, for a deployed pre-production test environment
            // that has no SMS provider yet -- but it makes every phone account
            // sign-in-able with one known code, so say so loudly.
            log.error("!!! OTP_MOCK_CODE is set under the prod profile: phone sign-in uses the fixed code {} and NO real "
                    + "SMS is sent. Anyone who knows a phone number can log in as that user. Unset OTP_MOCK_CODE and "
                    + "configure Twilio before real users arrive. !!!", otpMockCode);
        } else {
            // Without Twilio, phone-OTP codes are only written to the server log
            // (LoggingOtpSender) -- real users would never receive an SMS, and
            // anyone with log access could read every login code.
            checkNotBlank(problems, "TWILIO_ACCOUNT_SID (app.sms.twilio.account-sid)", twilioAccountSid);
            checkNotBlank(problems, "TWILIO_AUTH_TOKEN (app.sms.twilio.auth-token)", twilioAuthToken);
            if ((twilioFrom == null || twilioFrom.isBlank())
                    && (twilioMessagingServiceSid == null || twilioMessagingServiceSid.isBlank())) {
                problems.add("TWILIO_FROM (app.sms.twilio.from) or TWILIO_MESSAGING_SERVICE_SID "
                        + "(app.sms.twilio.messaging-service-sid) is not set");
            }
        }
        if (!problems.isEmpty()) {
            throw new IllegalStateException(
                    "Refusing to start with spring.profiles.active=prod while still using a committed dev-default "
                            + "secret, or missing required production configuration. Set a real value via "
                            + "environment variable before deploying to production: " + String.join("; ", problems));
        }
    }

    private static void checkOverridden(List<String> problems, String name, String actual, String devDefault) {
        if (actual == null || actual.isBlank()) {
            problems.add(name + " is not set");
        } else if (actual.equals(devDefault)) {
            problems.add(name + " is still the committed dev-default value");
        }
    }

    private static void checkNotBlank(List<String> problems, String name, String actual) {
        if (actual == null || actual.isBlank()) {
            problems.add(name + " is not set");
        }
    }
}
