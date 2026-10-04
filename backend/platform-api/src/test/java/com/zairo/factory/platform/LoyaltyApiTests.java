package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingCompletedEvent;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.loyalty.LoyaltyAccountRepository;
import com.zairo.factory.loyalty.LoyaltyBirthdayService;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.AdjustPointsRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.ApplyRedemptionRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.MilestoneRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.ReplaceMilestonesRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.RewardRequest;
import com.zairo.factory.loyalty.LoyaltyAdminDtos.UpdateLoyaltySettingsRequest;
import com.zairo.factory.loyalty.LoyaltyEarnLot;
import com.zairo.factory.loyalty.LoyaltyEarnLotRepository;
import com.zairo.factory.loyalty.LoyaltyLedgerService;
import com.zairo.factory.loyalty.LoyaltyProgram;
import com.zairo.factory.loyalty.LoyaltyProgramRepository;
import com.zairo.factory.loyalty.LoyaltyReferenceType;
import com.zairo.factory.loyalty.LoyaltyRewardType;
import com.zairo.factory.loyalty.LoyaltyTransaction;
import com.zairo.factory.loyalty.LoyaltyTransactionRepository;
import com.zairo.factory.loyalty.LoyaltyTransactionType;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.auth.AuthDtos.UpdateProfileRequest;
import java.math.BigDecimal;
import java.time.ZoneOffset;
import java.time.LocalDate;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * End-to-end against a real Postgres (Testcontainers), same style as
 * {@link CustomerIntelligenceApiTests}. Covers the whole customer/business
 * journey through the real HTTP surface -- earning rules, redemption,
 * duplicate-award protection, expiration, cross-business isolation, and
 * manual adjustments. The deterministic FIFO-consumption/lot-expiry
 * arithmetic itself has its own fast unit tests in {@code loyalty}'s own
 * {@code src/test}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestClock.class})
class LoyaltyApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private LoyaltyAccountRepository accountRepository;

    @Autowired
    private LoyaltyProgramRepository programRepository;

    @Autowired
    private LoyaltyTransactionRepository transactionRepository;

    @Autowired
    private LoyaltyEarnLotRepository earnLotRepository;

    @Autowired
    private LoyaltyLedgerService ledgerService;

    @Autowired
    private MutableClock clock;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    @Autowired
    private LoyaltyBirthdayService birthdayService;

    @BeforeEach
    void resetClockToRealNow() {
        clock.advanceTo(Instant.now());
    }

    @Test
    void completingABookingAwardsFixedAndPerSpendPoints() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-earn-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-earn-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Earn Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Haircut", new BigDecimal("40.00"));

        enableProgram(owner, providerId, settings(10, "1.00", 0, 0, 0, false, null));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(50); // 10 fixed + 40 from spend
    }

    @Test
    void cancelledAndNoShowBookingsEarnNoPoints() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-noearn-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-noearn-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty NoEarn Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Manicure", new BigDecimal("25.00"));
        enableProgram(owner, providerId, settings(100, "0", 0, 0, 0, false, null));

        Instant cancelledStart = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID cancelledSlot = createSlot(owner, providerId, cancelledStart, cancelledStart.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = createBooking(customer, providerId, serviceId, cancelledSlot);
        cancelBooking(customer, cancelledBookingId);

        Instant noShowStart = Instant.now().minus(1, ChronoUnit.DAYS);
        UUID noShowSlot = createSlot(owner, providerId, noShowStart, noShowStart.plus(30, ChronoUnit.MINUTES));
        UUID noShowBookingId = createBooking(customer, providerId, serviceId, noShowSlot);
        payBooking(customer, noShowBookingId);
        markNoShow(owner, noShowBookingId);

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);
    }

    @Test
    void firstBookingBonusIsAwardedOnceEvenAcrossTwoVisits() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-first-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-first-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty First Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Wash", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(0, "0", 500, 0, 0, false, null));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(2, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(500);

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(500); // still 500 -- no second bonus
    }

    @Test
    void repeatVisitBonusFiresExactlyOnceAtTheConfiguredThreshold() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-repeat-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-repeat-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Repeat Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Trim", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(0, "0", 0, 200, 0, false, null));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(3, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(2, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(200);

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(200); // no bonus on the 3rd visit
    }

    @Test
    void milestoneIsAwardedOnceWhenTheVisitThresholdIsReached() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-milestone-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-milestone-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Milestone Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Style", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(0, "0", 0, 0, 0, false, null));
        putMilestones(owner, providerId, List.of(new MilestoneRequest(3, 300, "Three visits")));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(4, ChronoUnit.DAYS));
        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(3, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(2, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(300);

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(300); // never re-awarded
    }

    @Test
    void reviewBonusIsAwardedOnceForALegitimateCompletedBookingReview() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-review-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-review-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Review Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Blowout", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(0, "0", 0, 0, 50, false, null));

        UUID slotId = createSlot(owner, providerId, Instant.now().minus(1, ChronoUnit.DAYS),
                Instant.now().minus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        payBooking(customer, bookingId);
        completeBooking(owner, bookingId);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);

        var reviewRequest = new CreateReviewRequest(5, "Loved it!");
        ResponseEntity<Map> reviewResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews",
                HttpMethod.POST, new HttpEntity<>(reviewRequest, TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(reviewResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(50);
    }

    @Test
    void redeemingARewardWithInsufficientPointsIsRejectedThenSucceedsOnceEarned() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-redeem-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-redeem-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Redeem Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Color", new BigDecimal("100.00"));
        enableProgram(owner, providerId, settings(0, "1.00", 0, 0, 0, false, null));
        UUID rewardId = createReward(owner, providerId, new RewardRequest("500 off", "Fixed discount",
                LoyaltyRewardType.FIXED_DISCOUNT, 1000, new BigDecimal("500.00"), "USD", null, null, null, null,
                null, "No cash value"));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(100);

        ResponseEntity<Map> insufficient = restTemplate.exchange("/api/v1/loyalty/rewards/" + rewardId + "/redeem",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(insufficient.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        for (int i = 0; i < 9; i++) {
            completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        }
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(1000);

        ResponseEntity<Map> redeemed = restTemplate.exchange("/api/v1/loyalty/rewards/" + rewardId + "/redeem",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(redeemed.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(redeemed.getBody().get("status")).isEqualTo("ACTIVE");
        String code = redeemed.getBody().get("code").toString();

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);

        // The business applies the code to a real booking of this same customer's.
        UUID applySlot = createSlot(owner, providerId, Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID applyBookingId = createBooking(customer, providerId, serviceId, applySlot);
        ResponseEntity<Map> applied = restTemplate.exchange(
                "/api/v1/business/" + providerId + "/loyalty/redemptions/" + code + "/apply", HttpMethod.POST,
                new HttpEntity<>(new ApplyRedemptionRequest(applyBookingId), TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(applied.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(applied.getBody().get("status")).isEqualTo("APPLIED");

        // Applying the same code again is rejected -- no double-spend of an already-used reward.
        ResponseEntity<Map> reapplied = restTemplate.exchange(
                "/api/v1/business/" + providerId + "/loyalty/redemptions/" + code + "/apply", HttpMethod.POST,
                new HttpEntity<>(new ApplyRedemptionRequest(applyBookingId), TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(reapplied.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void onlyOneOfTwoConcurrentRedemptionsForANearlyExhaustedBalanceSucceeds() throws InterruptedException {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-concurrent-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-concurrent-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Concurrent Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Cut", new BigDecimal("100.00"));
        enableProgram(owner, providerId, settings(0, "1.00", 0, 0, 0, false, null));
        UUID rewardId = createReward(owner, providerId, new RewardRequest("100 off", null,
                LoyaltyRewardType.FIXED_DISCOUNT, 100, new BigDecimal("100.00"), "USD", null, null, null, null,
                null, null));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(100); // exactly enough for one redemption

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger successes = new AtomicInteger();
        AtomicInteger conflicts = new AtomicInteger();

        Runnable attempt = () -> {
            ready.countDown();
            try {
                go.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            ResponseEntity<Map> response = restTemplate.exchange("/api/v1/loyalty/rewards/" + rewardId + "/redeem",
                    HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
            if (response.getStatusCode() == HttpStatus.CREATED) {
                successes.incrementAndGet();
            } else if (response.getStatusCode() == HttpStatus.CONFLICT) {
                conflicts.incrementAndGet();
            }
        };
        pool.submit(attempt);
        pool.submit(attempt);
        ready.await();
        go.countDown();
        pool.shutdown();
        assertThat(pool.awaitTermination(30, TimeUnit.SECONDS)).isTrue();

        assertThat(successes.get()).isEqualTo(1);
        assertThat(conflicts.get()).isEqualTo(1);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0); // never went negative
    }

    @Test
    void onlyOneOfTwoConcurrentApplicationsOfTheSameRedemptionCodeSucceeds() throws InterruptedException {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-apply-race-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "loy-apply-race-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Apply Race Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Cut", new BigDecimal("100.00"));
        enableProgram(owner, providerId, settings(0, "1.00", 0, 0, 0, false, null));
        UUID rewardId = createReward(owner, providerId, new RewardRequest("100 off", null,
                LoyaltyRewardType.FIXED_DISCOUNT, 100, new BigDecimal("100.00"), "USD", null, null, null, null, null,
                null));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        ResponseEntity<Map> redeemed = restTemplate.exchange("/api/v1/loyalty/rewards/" + rewardId + "/redeem",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(redeemed.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String code = redeemed.getBody().get("code").toString();

        UUID applySlot = createSlot(owner, providerId, Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID applyBookingId = createBooking(customer, providerId, serviceId, applySlot);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger successes = new AtomicInteger();
        AtomicInteger conflicts = new AtomicInteger();

        Runnable attempt = () -> {
            ready.countDown();
            try {
                go.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            ResponseEntity<Map> response = restTemplate.exchange(
                    "/api/v1/business/" + providerId + "/loyalty/redemptions/" + code + "/apply", HttpMethod.POST,
                    new HttpEntity<>(new ApplyRedemptionRequest(applyBookingId),
                            TestAuth.authHeaders(owner.accessToken())),
                    Map.class);
            if (response.getStatusCode() == HttpStatus.OK) {
                successes.incrementAndGet();
            } else if (response.getStatusCode() == HttpStatus.CONFLICT) {
                conflicts.incrementAndGet();
            }
        };
        pool.submit(attempt);
        pool.submit(attempt);
        ready.await();
        go.countDown();
        pool.shutdown();
        assertThat(pool.awaitTermination(30, TimeUnit.SECONDS)).isTrue();

        assertThat(successes.get()).isEqualTo(1);
        assertThat(conflicts.get()).isEqualTo(1);
    }

    @Test
    void refundingACompletedBookingsPaymentClawsBackItsEarnedPoints() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-refund-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-refund-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Refund Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Massage", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(50, "0", 0, 0, 0, false, null));

        UUID slotId = createSlot(owner, providerId, Instant.now().minus(1, ChronoUnit.DAYS),
                Instant.now().minus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        UUID paymentId = payBookingReturningPaymentId(customer, bookingId);
        completeBooking(owner, bookingId);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(50);

        TestPlatformAuth.Registered admin = TestPlatformAuth.registerPlatformAdmin(restTemplate,
                platformAdminAccountRepository, "loy-refund-admin-" + runId + "@factory.internal",
                PlatformRole.PLATFORM_ADMIN);
        ResponseEntity<Map> refundResponse = restTemplate.exchange("/api/v1/payments/" + paymentId + "/refund",
                HttpMethod.POST, new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())),
                Map.class);
        assertThat(refundResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);
        List<LoyaltyTransaction> history = transactionRepository
                .findByProviderIdAndUserIdOrderByCreatedAtDesc(providerId, customer.userId(), PageRequest.of(0, 10))
                .getContent();
        assertThat(history).extracting(LoyaltyTransaction::getType)
                .containsExactlyInAnyOrder(LoyaltyTransactionType.EARNED, LoyaltyTransactionType.REVERSAL);
    }

    @Test
    void refundReversalNeverTakesTheBalanceNegativeWhenPointsAlreadySpent() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-refund-spent-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "loy-refund-spent-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Refund Spent Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Massage", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(50, "0", 0, 0, 0, false, null));
        UUID rewardId = createReward(owner, providerId, new RewardRequest("30 off", null,
                LoyaltyRewardType.FIXED_DISCOUNT, 30, new BigDecimal("30.00"), "USD", null, null, null, null, null,
                null));

        UUID slotId = createSlot(owner, providerId, Instant.now().minus(1, ChronoUnit.DAYS),
                Instant.now().minus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        UUID paymentId = payBookingReturningPaymentId(customer, bookingId);
        completeBooking(owner, bookingId);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(50);

        // The customer spends 30 of the 50 points before the payment is
        // ever refunded -- only 20 are still there to claw back.
        ResponseEntity<Map> redeemed = restTemplate.exchange("/api/v1/loyalty/rewards/" + rewardId + "/redeem",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(redeemed.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(20);

        TestPlatformAuth.Registered admin = TestPlatformAuth.registerPlatformAdmin(restTemplate,
                platformAdminAccountRepository, "loy-refund-spent-admin-" + runId + "@factory.internal",
                PlatformRole.PLATFORM_ADMIN);
        ResponseEntity<Map> refundResponse = restTemplate.exchange("/api/v1/payments/" + paymentId + "/refund",
                HttpMethod.POST, new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())),
                Map.class);
        assertThat(refundResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Capped at the remaining balance -- never negative.
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);
    }

    @Test
    void manualAdjustmentRequiresAReasonAndNeverTakesTheBalanceNegative() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-adjust-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-adjust-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Adjust Salon " + runId);
        enableProgram(owner, providerId, settings(0, "0", 0, 0, 0, false, null));

        ResponseEntity<Map> blankReason = restTemplate.exchange(
                "/api/v1/business/" + providerId + "/loyalty/customers/" + customer.userId() + "/adjust",
                HttpMethod.POST, new HttpEntity<>(new AdjustPointsRequest(100, ""),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(blankReason.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<Map> credit = restTemplate.exchange(
                "/api/v1/business/" + providerId + "/loyalty/customers/" + customer.userId() + "/adjust",
                HttpMethod.POST, new HttpEntity<>(new AdjustPointsRequest(150, "Customer service goodwill"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(credit.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(credit.getBody().get("type")).isEqualTo("ADJUSTMENT");
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(150);

        ResponseEntity<Map> overDebit = restTemplate.exchange(
                "/api/v1/business/" + providerId + "/loyalty/customers/" + customer.userId() + "/adjust",
                HttpMethod.POST, new HttpEntity<>(new AdjustPointsRequest(-1000, "Correction"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(overDebit.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(150); // unchanged
    }

    @Test
    void aBusinessOwnerCannotReadAnotherBusinessesLoyaltySettings() {
        String runId = UUID.randomUUID().toString();
        Registered ownerA = TestAuth.registerOwner(restTemplate, "loy-iso-ownerA-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "loy-iso-ownerB-" + runId + "@example.com");
        UUID providerA = createProvider(ownerA, "Loyalty Isolation Salon A " + runId);

        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/business/" + providerA + "/loyalty/settings",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(ownerB.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void pointsEarnedAtOneBusinessAreCompletelyIsolatedFromAnother() {
        String runId = UUID.randomUUID().toString();
        Registered ownerA = TestAuth.registerOwner(restTemplate, "loy-cross-ownerA-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "loy-cross-ownerB-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-cross-customer-" + runId + "@example.com");

        UUID providerA = createProvider(ownerA, "Loyalty Cross Salon A " + runId);
        UUID serviceA = createService(ownerA, providerA, "Service A", new BigDecimal("20.00"));
        enableProgram(ownerA, providerA, settings(100, "0", 0, 0, 0, false, null));

        UUID providerB = createProvider(ownerB, "Loyalty Cross Salon B " + runId);
        UUID serviceB = createService(ownerB, providerB, "Service B", new BigDecimal("999.00"));
        enableProgram(ownerB, providerB, settings(5, "0", 0, 0, 0, false, null));

        completeVisit(ownerA, customer, providerA, serviceA, Instant.now().minus(1, ChronoUnit.DAYS));
        completeVisit(ownerB, customer, providerB, serviceB, Instant.now().minus(1, ChronoUnit.DAYS));

        assertThat(balanceOf(providerA, customer.userId())).isEqualTo(100);
        assertThat(balanceOf(providerB, customer.userId())).isEqualTo(5);
    }

    @Test
    void aDuplicatedBookingCompletedAwardNeverDoublesThePoints() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-dup-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-dup-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Dup Salon " + runId);
        enableProgram(owner, providerId, settings(0, "0", 0, 0, 0, false, null));
        LoyaltyProgram program = programRepository.findByProviderId(providerId).orElseThrow();

        UUID bookingId = UUID.randomUUID();
        ledgerService.earn(providerId, customer.userId(), 75, LoyaltyTransactionType.EARNED,
                LoyaltyReferenceType.BOOKING_EARNING, bookingId, bookingId, "Booking completed", program);
        // Simulates a retried/duplicated event delivery for the exact same booking.
        ledgerService.earn(providerId, customer.userId(), 75, LoyaltyTransactionType.EARNED,
                LoyaltyReferenceType.BOOKING_EARNING, bookingId, bookingId, "Booking completed", program);

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(75);
        assertThat(transactionRepository.findByProviderIdAndUserIdOrderByCreatedAtDesc(providerId, customer.userId(),
                PageRequest.of(0, 10)).getTotalElements()).isEqualTo(1);
    }

    /**
     * Exercises the real {@code LoyaltyEarningListener -> loyalty_outbox_event
     * -> LoyaltyOutboxProcessor} pipeline end to end (Phase 0
     * stabilization), not just {@code LoyaltyLedgerService#earn}'s own
     * idempotency (see the test above) -- a genuinely duplicated {@code
     * BookingCompletedEvent} delivery (the actual scenario this pipeline
     * exists to survive: a retried event, an application restart mid-sweep)
     * creates a second, distinct outbox row, and processing that second row
     * must still land on exactly one earning.
     */
    @Test
    void aSecondBookingCompletedEventDeliveryForTheSameBookingProcessesAsASafeNoOp() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-dup-event-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "loy-dup-event-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Dup Event Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Wash", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(60, "0", 0, 0, 0, false, null));

        Instant start = Instant.now().minus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        payBooking(customer, bookingId);
        completeBooking(owner, bookingId);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(60);

        // A second, independent delivery of the same event -- e.g. a
        // process restart between the original commit and its own outbox
        // row being marked processed, followed by whatever re-derives and
        // republishes it. Creates its own new loyalty_outbox_event row
        // (this is not the same call as the ledger-level test above).
        eventPublisher.publishEvent(new BookingCompletedEvent(bookingId, customer.userId(), providerId, serviceId));

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(60); // unchanged -- no double award
        assertThat(transactionRepository.findByProviderIdAndUserIdOrderByCreatedAtDesc(providerId, customer.userId(),
                PageRequest.of(0, 10)).getTotalElements()).isEqualTo(1);
    }

    @Test
    void expiredPointsAreDeductedByTheSweepAndTheHistoryStaysAuditable() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-expire-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-expire-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Expire Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Facial", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settings(200, "0", 0, 0, 0, true, 1));

        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(200);

        clock.advanceTo(Instant.now().plus(400, ChronoUnit.DAYS));

        List<LoyaltyEarnLot> dueLots = earnLotRepository
                .findByExpiresAtBeforeAndPointsRemainingGreaterThanOrderByExpiresAtAsc(clock.instant(), 0,
                        PageRequest.of(0, 10));
        assertThat(dueLots).hasSize(1);
        int expired = ledgerService.expireLot(dueLots.get(0).getId());
        assertThat(expired).isEqualTo(200);

        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(0);
        List<LoyaltyTransaction> history = transactionRepository
                .findByProviderIdAndUserIdOrderByCreatedAtDesc(providerId, customer.userId(),
                        PageRequest.of(0, 10)).getContent();
        assertThat(history).extracting(LoyaltyTransaction::getType)
                .containsExactlyInAnyOrder(LoyaltyTransactionType.EARNED, LoyaltyTransactionType.EXPIRED);
    }

    @Test
    void birthdayBonusIsAwardedOnceToOptedInMembersOnTheirBirthday() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-bday-owner-" + runId + "@example.com");
        Registered optedIn = TestAuth.registerCustomer(restTemplate, "loy-bday-in-" + runId + "@example.com");
        Registered optedOut = TestAuth.registerCustomer(restTemplate, "loy-bday-out-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Birthday Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Haircut", new BigDecimal("40.00"));
        enableProgram(owner, providerId, settingsWithBirthdayBonus(10, 100));

        // Both become members by completing a visit (10 points each).
        completeVisit(owner, optedIn, providerId, serviceId, Instant.now().minus(2, ChronoUnit.DAYS));
        completeVisit(owner, optedOut, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));

        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        setBirthday(optedIn, today.minusYears(30), true);
        setBirthday(optedOut, today.minusYears(30), false); // birthday today, but no consent

        assertThat(runBirthdaySweep(providerId, today)).isEqualTo(1);
        assertThat(balanceOf(providerId, optedIn.userId())).isEqualTo(110);
        assertThat(balanceOf(providerId, optedOut.userId())).isEqualTo(10);

        // The sweep runs hourly: a re-run the same day must not pay twice.
        assertThat(runBirthdaySweep(providerId, today)).isEqualTo(0);
        assertThat(balanceOf(providerId, optedIn.userId())).isEqualTo(110);

        ResponseEntity<List> birthdays = restTemplate.exchange("/api/v1/business/" + providerId
                + "/loyalty/birthdays?days=7", HttpMethod.GET,
                new HttpEntity<>(TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(birthdays.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(birthdays.getBody()).hasSize(1); // the opted-out member is never listed
        Map<?, ?> entry = (Map<?, ?>) birthdays.getBody().get(0);
        assertThat(entry.get("userId")).isEqualTo(optedIn.userId().toString());
        assertThat(entry.get("daysUntil")).isEqualTo(0);
        assertThat(entry.get("bonusPoints")).isEqualTo(100);
        assertThat(entry.get("bonusAwarded")).isEqualTo(true);
        assertThat(entry.containsKey("birthDate")).isFalse(); // age/year is never exposed to the business
    }

    @Test
    void noBirthdayBonusIsAwardedWhenTheProgramDoesNotGrantOne() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-bday0-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-bday0-cust-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty NoBirthday Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Wash", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settingsWithBirthdayBonus(10, 0));
        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        setBirthday(customer, today.minusYears(25), true);

        assertThat(runBirthdaySweep(providerId, today)).isEqualTo(0);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(10);
    }

    private ResponseEntity<Map> greet(Registered owner, UUID providerId, UUID userId, String message,
            Integer bonusPoints) {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("message", message);
        body.put("bonusPoints", bonusPoints);
        return restTemplate.exchange("/api/v1/business/" + providerId + "/loyalty/customers/" + userId + "/greet",
                HttpMethod.POST, new HttpEntity<>(body, TestAuth.authHeaders(owner.accessToken())), Map.class);
    }

    @Test
    void anOwnerCanGreetAnOptedInMemberOnceADayWithAGiftOfPoints() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-greet-owner-" + runId + "@example.com");
        Registered optedIn = TestAuth.registerCustomer(restTemplate, "loy-greet-in-" + runId + "@example.com");
        Registered optedOut = TestAuth.registerCustomer(restTemplate, "loy-greet-out-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "loy-greet-other-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty Greeting Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Haircut", new BigDecimal("40.00"));
        enableProgram(owner, providerId, settingsWithBirthdayBonus(10, 0));
        completeVisit(owner, optedIn, providerId, serviceId, Instant.now().minus(2, ChronoUnit.DAYS));
        completeVisit(owner, optedOut, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        setBirthday(optedIn, LocalDate.now(ZoneOffset.UTC).minusYears(30), true);
        setBirthday(optedOut, LocalDate.now(ZoneOffset.UTC).minusYears(30), false);

        // Not opted in -> refused; nothing moves.
        assertThat(greet(owner, providerId, optedOut.userId(), "Happy birthday!", 50).getStatusCode())
                .isEqualTo(HttpStatus.CONFLICT);
        // Over the cap -> 400.
        assertThat(greet(owner, providerId, optedIn.userId(), null, 1001).getStatusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
        // Somebody else's business -> not allowed.
        assertThat(greet(otherOwner, providerId, optedIn.userId(), null, 5).getStatusCode().is2xxSuccessful())
                .isFalse();

        ResponseEntity<Map> sent = greet(owner, providerId, optedIn.userId(), "Come in for a treat!", 50);
        assertThat(sent.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(sent.getBody().get("bonusPoints")).isEqualTo(50);
        assertThat(balanceOf(providerId, optedIn.userId())).isEqualTo(60); // 10 from the visit + 50 gift

        // A second greeting the same day is refused and does not pay twice.
        assertThat(greet(owner, providerId, optedIn.userId(), null, 50).getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(balanceOf(providerId, optedIn.userId())).isEqualTo(60);

        ResponseEntity<List> birthdays = restTemplate.exchange("/api/v1/business/" + providerId
                + "/loyalty/birthdays?days=1", HttpMethod.GET,
                new HttpEntity<>(TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(((Map<?, ?>) birthdays.getBody().get(0)).get("greetedToday")).isEqualTo(true);
    }

    @Test
    void aTextOnlyGreetingNeedsNoPointsAndNoProgram() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "loy-greet0-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "loy-greet0-cust-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Loyalty TextGreeting Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Wash", new BigDecimal("10.00"));
        enableProgram(owner, providerId, settingsWithBirthdayBonus(10, 0));
        completeVisit(owner, customer, providerId, serviceId, Instant.now().minus(1, ChronoUnit.DAYS));
        setBirthday(customer, LocalDate.now(ZoneOffset.UTC).minusYears(25), true);

        assertThat(greet(owner, providerId, customer.userId(), "Warm wishes!", null).getStatusCode())
                .isEqualTo(HttpStatus.CREATED);
        assertThat(balanceOf(providerId, customer.userId())).isEqualTo(10); // unchanged
    }

    private int balanceOf(UUID providerId, UUID userId) {
        return accountRepository.findByProviderIdAndUserId(providerId, userId).map(a -> a.getPointsBalance())
                .orElse(0);
    }

    private void enableProgram(Registered owner, UUID providerId, UpdateLoyaltySettingsRequest settings) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/business/" + providerId + "/loyalty/settings",
                HttpMethod.PUT, new HttpEntity<>(settings, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private void putMilestones(Registered owner, UUID providerId, List<MilestoneRequest> milestones) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/business/" + providerId + "/loyalty/milestones",
                HttpMethod.PUT, new HttpEntity<>(new ReplaceMilestonesRequest(milestones),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private UUID createReward(Registered owner, UUID providerId, RewardRequest request) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/business/" + providerId + "/loyalty/rewards",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private static UpdateLoyaltySettingsRequest settings(int fixedPointsPerBooking, String pointsPerCurrencyUnit,
            int firstBookingBonusPoints, int repeatVisitBonusPoints, int reviewBonusPoints, boolean expireEnabled,
            Integer expirationMonths) {
        return new UpdateLoyaltySettingsRequest(true, "Loyalty Rewards", "Earn and redeem points",
                fixedPointsPerBooking, new BigDecimal(pointsPerCurrencyUnit), firstBookingBonusPoints,
                repeatVisitBonusPoints, 2, reviewBonusPoints, null, null, null, expireEnabled, expirationMonths, null,
                null, 0);
    }

    private static UpdateLoyaltySettingsRequest settingsWithBirthdayBonus(int fixedPointsPerBooking,
            int birthdayBonusPoints) {
        return new UpdateLoyaltySettingsRequest(true, "Loyalty Rewards", "Earn and redeem points",
                fixedPointsPerBooking, BigDecimal.ZERO, 0, 0, 2, 0, null, null, null, false, null, null, null,
                birthdayBonusPoints);
    }

    private void setBirthday(Registered customer, LocalDate birthDate, boolean consent) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auth/me", HttpMethod.PATCH,
                new HttpEntity<>(new UpdateProfileRequest(null, null, birthDate, null, null, consent),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    /** What LoyaltyBirthdayJob does for one program, driven through the same public service API. */
    private int runBirthdaySweep(UUID providerId, LocalDate today) {
        LoyaltyProgram program = programRepository.findByProviderId(providerId).orElseThrow();
        int awarded = 0;
        for (UUID userId : birthdayService.birthdayMemberIds(program, today)) {
            if (birthdayService.awardOne(program, userId, today.getYear())) {
                awarded++;
            }
        }
        return awarded;
    }

    private void completeVisit(Registered owner, Registered customer, UUID providerId, UUID serviceId,
            Instant startsAt) {
        UUID slotId = createSlot(owner, providerId, startsAt, startsAt.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = createBooking(customer, providerId, serviceId, slotId);
        payBooking(customer, bookingId);
        completeBooking(owner, bookingId);
    }

    private void payBooking(Registered customer, UUID bookingId) {
        payBookingReturningPaymentId(customer, bookingId);
    }

    private UUID payBookingReturningPaymentId(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private void completeBooking(Registered owner, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
    }

    private void cancelBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private void markNoShow(Registered owner, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/no-show",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createService(Registered owner, UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createSlot(Registered owner, UUID providerId, Instant startsAt, Instant endsAt) {
        var request = new CreateAvailabilitySlotRequest(startsAt, endsAt);
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createBooking(Registered customer, UUID providerId, UUID serviceId, UUID slotId) {
        var request = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("0.00"));
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
