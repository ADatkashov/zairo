package com.zairo.factory.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * Plain unit test, no Spring/DB context — same shape as
 * LoginAttemptLimiterTest. FakePhoneOtpRepository is a tiny in-memory
 * stand-in made possible by PhoneOtpRepository's narrow, explicit method
 * list (see that interface's own doc comment); MutableClock lets expiry/
 * cooldown be tested deterministically instead of sleeping.
 */
class PhoneOtpServiceTest {

    private static final String PHONE = "+77001234567";

    private final FakePhoneOtpRepository repository = new FakePhoneOtpRepository();
    private final CapturingOtpSender sender = new CapturingOtpSender();
    private final MutableClock clock = new MutableClock(Instant.parse("2026-01-01T00:00:00Z"));

    private PhoneOtpService newService(long ttlMinutes, long resendCooldownSeconds, int maxAttempts,
            int maxRequestsPerHour) {
        return new PhoneOtpService(repository, sender, clock, ttlMinutes, resendCooldownSeconds, maxAttempts,
                maxRequestsPerHour);
    }

    private PhoneOtpService newLimitedService(int maxRequestsPerIpPerHour, int dailySendCap) {
        return new PhoneOtpService(repository, sender, clock, 5, 0, 5, 100, maxRequestsPerIpPerHour, dailySendCap, "");
    }

    @Test
    void aMockCodeIsIssuedForEveryPhoneAndVerifiesNormally() {
        PhoneOtpService service = new PhoneOtpService(repository, sender, clock, 5, 0, 5, 100,
                Integer.MAX_VALUE, Integer.MAX_VALUE, "123456");

        service.requestOtp("+77001111111");
        assertThat(sender.lastCode).isEqualTo("123456");
        service.requestOtp("+77002222222");
        assertThat(sender.lastCode).isEqualTo("123456");

        service.verify("+77001111111", "123456"); // accepted
        assertThatThrownBy(() -> service.verify("+77001111111", "123456"))
                .isInstanceOf(InvalidOtpException.class); // still single-use
        assertThatThrownBy(() -> service.verify("+77002222222", "654321"))
                .isInstanceOf(InvalidOtpException.class); // other codes still rejected
    }

    @Test
    void aMalformedMockCodeIsRejectedAtStartup() {
        assertThatThrownBy(() -> new PhoneOtpService(repository, sender, clock, 5, 0, 5, 100,
                Integer.MAX_VALUE, Integer.MAX_VALUE, "12ab")).isInstanceOf(IllegalStateException.class);
    }

    @Test
    void oneIpCannotRequestCodesForManyPhonesPastItsHourlyCap() {
        PhoneOtpService service = newLimitedService(2, 1000);
        service.requestOtp("+77001111111", "1.2.3.4");
        service.requestOtp("+77002222222", "1.2.3.4");

        assertThatThrownBy(() -> service.requestOtp("+77003333333", "1.2.3.4"))
                .isInstanceOf(TooManyOtpRequestsException.class);
        // A different IP is unaffected, and the window slides.
        service.requestOtp("+77003333333", "5.6.7.8");
        clock.advanceBy(Duration.ofHours(1).plusSeconds(1));
        service.requestOtp("+77004444444", "1.2.3.4");
    }

    @Test
    void theDailyCapStopsAllSendingOnceReached() {
        PhoneOtpService service = newLimitedService(100, 2);
        service.requestOtp("+77001111111", "1.2.3.4");
        service.requestOtp("+77002222222", "5.6.7.8");

        assertThatThrownBy(() -> service.requestOtp("+77003333333", "9.9.9.9"))
                .isInstanceOf(OtpTemporarilyUnavailableException.class);
        assertThat(sender.sent).hasSize(2);
    }

    @Test
    void requestingSendsASixDigitCodeAndVerifyAcceptsIt() {
        PhoneOtpService service = newService(5, 60, 5, 5);
        service.requestOtp(PHONE);

        assertThat(sender.lastCode).matches("\\d{6}");
        service.verify(PHONE, sender.lastCode); // does not throw
    }

    @Test
    void wrongCodeIsRejected() {
        PhoneOtpService service = newService(5, 60, 5, 5);
        service.requestOtp(PHONE);

        assertThatThrownBy(() -> service.verify(PHONE, "000000")).isInstanceOf(InvalidOtpException.class);
    }

    @Test
    void verifyingWithNoOtpEverRequestedIsRejected() {
        PhoneOtpService service = newService(5, 60, 5, 5);

        assertThatThrownBy(() -> service.verify(PHONE, "123456")).isInstanceOf(InvalidOtpException.class);
    }

    @Test
    void aCodeCannotBeReplayedAfterItWasAlreadyConsumed() {
        PhoneOtpService service = newService(5, 60, 5, 5);
        service.requestOtp(PHONE);
        String code = sender.lastCode;
        service.verify(PHONE, code);

        assertThatThrownBy(() -> service.verify(PHONE, code)).isInstanceOf(InvalidOtpException.class);
    }

    @Test
    void anExpiredCodeIsRejectedEvenIfCorrect() {
        PhoneOtpService service = newService(5, 60, 5, 5);
        service.requestOtp(PHONE);
        String code = sender.lastCode;

        clock.advanceBy(Duration.ofMinutes(6));

        assertThatThrownBy(() -> service.verify(PHONE, code)).isInstanceOf(OtpExpiredException.class);
    }

    @Test
    void locksOutAfterTooManyWrongAttempts() {
        PhoneOtpService service = newService(5, 60, 3, 5);
        service.requestOtp(PHONE);
        String correctCode = sender.lastCode;

        for (int i = 0; i < 3; i++) {
            assertThatThrownBy(() -> service.verify(PHONE, "000000")).isInstanceOf(InvalidOtpException.class);
        }

        // Even the correct code is now rejected — the attempt budget for
        // *this* code is spent; the caller must request a new one.
        assertThatThrownBy(() -> service.verify(PHONE, correctCode)).isInstanceOf(TooManyOtpAttemptsException.class);
    }

    @Test
    void resendWithinTheCooldownIsRejected() {
        PhoneOtpService service = newService(5, 60, 5, 5);
        service.requestOtp(PHONE);

        assertThatThrownBy(() -> service.requestOtp(PHONE)).isInstanceOf(OtpResendCooldownException.class);
    }

    @Test
    void resendAfterTheCooldownHasPassedSucceeds() {
        PhoneOtpService service = newService(5, 60, 5, 5);
        service.requestOtp(PHONE);
        String firstCode = sender.lastCode;

        clock.advanceBy(Duration.ofSeconds(61));
        service.requestOtp(PHONE);

        assertThat(sender.lastCode).isNotEqualTo(firstCode);
        service.verify(PHONE, sender.lastCode); // the newest code is the one that's live
    }

    @Test
    void tooManyRequestsInAnHourAreRejectedEvenPastTheCooldown() {
        PhoneOtpService service = newService(5, 0, 5, 2);
        service.requestOtp(PHONE);
        service.requestOtp(PHONE);

        assertThatThrownBy(() -> service.requestOtp(PHONE)).isInstanceOf(TooManyOtpRequestsException.class);
    }

    @Test
    void requestsMoreThanAnHourApartDoNotCountTowardTheHourlyCap() {
        PhoneOtpService service = newService(5, 0, 5, 2);
        service.requestOtp(PHONE);
        service.requestOtp(PHONE);

        clock.advanceBy(Duration.ofHours(1).plusSeconds(1));

        service.requestOtp(PHONE); // does not throw -- the earlier two have aged out of the 1h window
    }

    @Test
    void aConsumedCodeCannotBeVerifiedASecondTime() {
        // Simulates the race CLAUDE.md task spec §17 calls out (OTP replay
        // under concurrency): two requests both see the same unconsumed
        // code, but PhoneOtpRepository.consume's atomic "UPDATE ... WHERE
        // consumed_at IS NULL" semantics (faked the same way here) must let
        // only the first one through.
        PhoneOtpService service = newService(5, 60, 5, 5);
        service.requestOtp(PHONE);
        String code = sender.lastCode;

        service.verify(PHONE, code);

        assertThatThrownBy(() -> service.verify(PHONE, code)).isInstanceOf(InvalidOtpException.class);
    }

    private static final class CapturingOtpSender implements OtpSenderPort {
        private String lastCode;
        private final java.util.List<String> sent = new java.util.ArrayList<>();

        @Override
        public void send(String e164Phone, String code) {
            this.lastCode = code;
            this.sent.add(e164Phone);
        }
    }

    private static final class MutableClock extends Clock {
        private Instant now;

        MutableClock(Instant start) {
            this.now = start;
        }

        void advanceBy(Duration amount) {
            now = now.plus(amount);
        }

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    /** In-memory PhoneOtpRepository — see that interface's doc comment on why this is small enough to hand-write. */
    private static final class FakePhoneOtpRepository implements PhoneOtpRepository {
        private final Map<UUID, PhoneOtp> rows = new LinkedHashMap<>();

        @Override
        public PhoneOtp save(PhoneOtp otp) {
            rows.put(otp.getId(), otp);
            return otp;
        }

        @Override
        public Optional<PhoneOtp> findTopByPhoneOrderByCreatedAtDesc(String phone) {
            return rows.values().stream()
                    .filter(o -> o.getPhone().equals(phone))
                    .max((a, b) -> a.getCreatedAt().compareTo(b.getCreatedAt()));
        }

        @Override
        public long countByPhoneAndCreatedAtAfter(String phone, Instant since) {
            return rows.values().stream()
                    .filter(o -> o.getPhone().equals(phone) && o.getCreatedAt().isAfter(since))
                    .count();
        }

        @Override
        public long countByRequestIpAndCreatedAtAfter(String requestIp, Instant since) {
            return rows.values().stream()
                    .filter(o -> requestIp.equals(o.getRequestIp()) && o.getCreatedAt().isAfter(since))
                    .count();
        }

        @Override
        public long countByCreatedAtAfter(Instant since) {
            return rows.values().stream().filter(o -> o.getCreatedAt().isAfter(since)).count();
        }

        @Override
        public int consume(UUID id, Instant now) {
            PhoneOtp otp = rows.get(id);
            if (otp == null || otp.isConsumed()) {
                return 0;
            }
            otp.consume(now);
            return 1;
        }

        @Override
        public void incrementAttempts(UUID id) {
            PhoneOtp otp = rows.get(id);
            if (otp != null) {
                otp.incrementAttempts();
            }
        }
    }
}
