package com.zairo.factory.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * OTP lifecycle for phone verification: generate, rate-limit requests,
 * verify, and enforce one-time use — everything in Threat model item
 * "OTP brute force / replay / enumeration" (see CLAUDE.md task spec §17).
 * Phone numbers passed in here are always already normalized (see
 * PhoneNumberNormalizer) — this class never sees the raw, user-typed form.
 */
@Component
class PhoneOtpService {

    private static final int CODE_LENGTH = 6;
    private static final int CODE_UPPER_BOUND = 1_000_000;

    private final PhoneOtpRepository phoneOtpRepository;
    private final OtpSenderPort otpSender;
    private final Clock clock;
    private final SecureRandom secureRandom = new SecureRandom();
    private final Duration ttl;
    private final Duration resendCooldown;
    private final int maxAttempts;
    private final int maxRequestsPerHour;
    private final int maxRequestsPerIpPerHour;
    private final int dailySendCap;
    private final String mockCode; // blank = real random codes

    // Explicit @Autowired is required here: with two constructors and
    // neither a no-arg one, Spring can't infer which to use on its own —
    // without this it fails bean creation at startup with "No default
    // constructor found" (see git history for the exact incident). The
    // other constructor below is a test-only seam Spring must never pick.
    @Autowired
    PhoneOtpService(PhoneOtpRepository phoneOtpRepository, OtpSenderPort otpSender,
            @Value("${app.otp.ttl-minutes:5}") long ttlMinutes,
            @Value("${app.otp.resend-cooldown-seconds:60}") long resendCooldownSeconds,
            @Value("${app.otp.max-verify-attempts:5}") int maxAttempts,
            @Value("${app.otp.max-requests-per-hour:5}") int maxRequestsPerHour,
            @Value("${app.otp.max-requests-per-ip-per-hour:20}") int maxRequestsPerIpPerHour,
            @Value("${app.otp.daily-send-cap:3000}") int dailySendCap,
            @Value("${app.otp.mock-code:}") String mockCode) {
        this(phoneOtpRepository, otpSender, Clock.systemUTC(), ttlMinutes, resendCooldownSeconds, maxAttempts,
                maxRequestsPerHour, maxRequestsPerIpPerHour, dailySendCap, mockCode);
    }

    /** Test-only seam with the IP/daily limits effectively off — see PhoneOtpServiceTest. */
    PhoneOtpService(PhoneOtpRepository phoneOtpRepository, OtpSenderPort otpSender, Clock clock, long ttlMinutes,
            long resendCooldownSeconds, int maxAttempts, int maxRequestsPerHour) {
        this(phoneOtpRepository, otpSender, clock, ttlMinutes, resendCooldownSeconds, maxAttempts,
                maxRequestsPerHour, Integer.MAX_VALUE, Integer.MAX_VALUE, "");
    }

    /** Test-only seam — see PhoneOtpServiceTest, which needs to fast-forward past expiry/cooldown without sleeping. */
    PhoneOtpService(PhoneOtpRepository phoneOtpRepository, OtpSenderPort otpSender, Clock clock, long ttlMinutes,
            long resendCooldownSeconds, int maxAttempts, int maxRequestsPerHour, int maxRequestsPerIpPerHour,
            int dailySendCap, String mockCode) {
        if (mockCode != null && !mockCode.isBlank() && !mockCode.matches("\\d{6}")) {
            throw new IllegalStateException("app.otp.mock-code (OTP_MOCK_CODE) must be exactly 6 digits");
        }
        this.mockCode = mockCode == null ? "" : mockCode.trim();
        this.phoneOtpRepository = phoneOtpRepository;
        this.otpSender = otpSender;
        this.clock = clock;
        this.ttl = Duration.ofMinutes(ttlMinutes);
        this.resendCooldown = Duration.ofSeconds(resendCooldownSeconds);
        this.maxAttempts = maxAttempts;
        this.maxRequestsPerHour = maxRequestsPerHour;
        this.maxRequestsPerIpPerHour = maxRequestsPerIpPerHour;
        this.dailySendCap = dailySendCap;
    }

    /**
     * @throws OtpResendCooldownException if the last code for this phone was requested too recently.
     * @throws TooManyOtpRequestsException if this phone already requested too many codes in the last hour.
     */
    @Transactional
    void requestOtp(String e164Phone) {
        requestOtp(e164Phone, null);
    }

    /**
     * Besides the per-phone cooldown/hourly cap, two limits that bound SMS
     * spend against pumping fraud (bots requesting codes for many numbers):
     * a per-IP hourly cap and a platform-wide daily cap. {@code clientIp} may
     * be null (unknown) — then only the per-phone and daily limits apply.
     *
     * @throws OtpTemporarilyUnavailableException the platform-wide daily SMS cap is reached.
     */
    @Transactional
    void requestOtp(String e164Phone, String clientIp) {
        Instant now = Instant.now(clock);
        Optional<PhoneOtp> last = phoneOtpRepository.findTopByPhoneOrderByCreatedAtDesc(e164Phone);
        if (last.isPresent() && last.get().getCreatedAt().plus(resendCooldown).isAfter(now)) {
            throw new OtpResendCooldownException("Please wait before requesting another code");
        }
        long recentRequests = phoneOtpRepository.countByPhoneAndCreatedAtAfter(e164Phone, now.minus(Duration.ofHours(1)));
        if (recentRequests >= maxRequestsPerHour) {
            throw new TooManyOtpRequestsException("Too many codes requested for this phone — try again later");
        }

        if (clientIp != null && phoneOtpRepository.countByRequestIpAndCreatedAtAfter(clientIp,
                now.minus(Duration.ofHours(1))) >= maxRequestsPerIpPerHour) {
            throw new TooManyOtpRequestsException("Too many codes requested from this network — try again later");
        }
        if (phoneOtpRepository.countByCreatedAtAfter(now.minus(Duration.ofDays(1))) >= dailySendCap) {
            throw new OtpTemporarilyUnavailableException("SMS codes are temporarily unavailable — try again later");
        }

        String code = generateCode();
        PhoneOtp otp = new PhoneOtp(UUID.randomUUID(), e164Phone, hash(code), now.plus(ttl), now, clientIp);
        phoneOtpRepository.save(otp);
        otpSender.send(e164Phone, code);
    }

    /**
     * Verifies and atomically consumes the most recent code for this phone.
     * Never returns a distinct reason for "wrong code" vs. "no code was ever
     * requested" — same don't-help-an-attacker-enumerate reasoning as
     * {@link InvalidProviderCredentialException}.
     *
     * @throws InvalidOtpException wrong code, already consumed, or none exists.
     * @throws OtpExpiredException the most recent code has expired.
     * @throws TooManyOtpAttemptsException too many wrong attempts against the current code.
     */
    @Transactional
    void verify(String e164Phone, String code) {
        PhoneOtp otp = phoneOtpRepository.findTopByPhoneOrderByCreatedAtDesc(e164Phone)
                .orElseThrow(() -> new InvalidOtpException("Invalid or expired code"));
        Instant now = Instant.now(clock);

        if (otp.isConsumed()) {
            throw new InvalidOtpException("Invalid or expired code");
        }
        if (otp.isExpired(now)) {
            throw new OtpExpiredException("This code has expired — request a new one");
        }
        if (otp.getAttempts() >= maxAttempts) {
            throw new TooManyOtpAttemptsException("Too many incorrect attempts — request a new code");
        }

        if (!MessageDigest.isEqual(hash(code).getBytes(StandardCharsets.UTF_8),
                otp.getCodeHash().getBytes(StandardCharsets.UTF_8))) {
            phoneOtpRepository.incrementAttempts(otp.getId());
            throw new InvalidOtpException("Invalid or expired code");
        }

        // Race-safe: see PhoneOtpRepository.consume's doc comment. If this
        // returns 0, a concurrent request already consumed the exact same
        // code first — reject this one too rather than letting two
        // requests both succeed off one code.
        int updated = phoneOtpRepository.consume(otp.getId(), now);
        if (updated == 0) {
            throw new InvalidOtpException("Invalid or expired code");
        }
    }

    private String generateCode() {
        if (!mockCode.isEmpty()) {
            return mockCode;
        }
        int value = secureRandom.nextInt(CODE_UPPER_BOUND);
        return String.format("%0" + CODE_LENGTH + "d", value);
    }

    private static String hash(String code) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(code.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}
