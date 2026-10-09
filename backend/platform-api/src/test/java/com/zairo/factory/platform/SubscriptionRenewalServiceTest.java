package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platform.TestClock.MutableClock;
import com.zairo.factory.platform.TestPayments.FailureController;
import com.zairo.factory.subscriptions.SubscriptionRenewalService;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * {@link SubscriptionRenewalService}'s renewal/grace-period logic, driven
 * deterministically by {@link TestClock}'s controllable clock instead of
 * waiting on {@link com.zairo.factory.subscriptions.SubscriptionRenewalJob}'s
 * real daily cron — the job itself is a one-line {@code @Scheduled} wrapper
 * (see its own class doc), nothing to test there beyond "it calls the
 * service", which these tests exercise directly by calling the service's
 * public methods the same way the job would.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class, TestClock.class})
class SubscriptionRenewalServiceTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private SubscriptionRenewalService subscriptionRenewalService;

    @Autowired
    private MutableClock clock;

    @Autowired
    private FailureController failureController;

    @Test
    void aSuccessfulRenewalAdvancesThePeriodAndKeepsThePlanActive() {
        String runId = java.util.UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-ok-" + runId + "@example.com");
        Map<?, ?> upgraded = upgrade(owner);
        Instant originalPeriodEnd = Instant.parse(upgraded.get("currentPeriodEnd").toString());

        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.renewDueSubscriptions();

        Map<?, ?> renewed = getMine(owner);
        assertThat(renewed.get("plan")).isEqualTo("PRO");
        assertThat(renewed.get("status")).isEqualTo("ACTIVE");
        assertThat(Instant.parse(renewed.get("currentPeriodEnd").toString())).isAfter(originalPeriodEnd);
    }

    @Test
    void aFailedRenewalChargeEntersPastDueWithASevenDayGracePeriod() {
        String runId = java.util.UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-fail-" + runId + "@example.com");
        Map<?, ?> upgraded = upgrade(owner);
        Instant originalPeriodEnd = Instant.parse(upgraded.get("currentPeriodEnd").toString());

        declineRenewalCharges(owner, 1);
        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.renewDueSubscriptions();

        Map<?, ?> pastDue = getMine(owner);
        assertThat(pastDue.get("plan")).isEqualTo("PRO");
        assertThat(pastDue.get("status")).isEqualTo("PAST_DUE");
        Instant gracePeriodEndsAt = Instant.parse(pastDue.get("gracePeriodEndsAt").toString());
        assertThat(gracePeriodEndsAt).isCloseTo(clock.instant().plus(7, ChronoUnit.DAYS),
                org.assertj.core.api.Assertions.within(1, ChronoUnit.SECONDS));
    }

    @Test
    void aPastDueSubscriptionIsDowngradedToFreeOnceItsGracePeriodExpires() {
        String runId = java.util.UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-downgrade-" + runId + "@example.com");
        Map<?, ?> upgraded = upgrade(owner);
        Instant originalPeriodEnd = Instant.parse(upgraded.get("currentPeriodEnd").toString());

        declineRenewalCharges(owner, 1);
        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.renewDueSubscriptions();
        assertThat(getMine(owner).get("status")).isEqualTo("PAST_DUE");

        // Still within the grace period: not downgraded yet.
        clock.advanceTo(clock.instant().plus(3, ChronoUnit.DAYS));
        subscriptionRenewalService.downgradeExpiredGracePeriods();
        assertThat(getMine(owner).get("plan")).isEqualTo("PRO");

        // Past the 7-day grace period: downgraded.
        clock.advanceTo(clock.instant().plus(5, ChronoUnit.DAYS));
        subscriptionRenewalService.downgradeExpiredGracePeriods();
        Map<?, ?> downgraded = getMine(owner);
        assertThat(downgraded.get("plan")).isEqualTo("FREE");
        assertThat(downgraded.get("status")).isEqualTo("ACTIVE");
    }

    @Test
    void aSelfServiceDowngradeTakesEffectAtTheRenewalBoundaryInsteadOfBeingCharged() {
        String runId = java.util.UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-selfservice-" + runId + "@example.com");
        Map<?, ?> upgraded = upgrade(owner);
        Instant originalPeriodEnd = Instant.parse(upgraded.get("currentPeriodEnd").toString());
        downgrade(owner);

        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.renewDueSubscriptions();

        Map<?, ?> result = getMine(owner);
        assertThat(result.get("plan")).isEqualTo("FREE");
        assertThat(result.get("status")).isEqualTo("ACTIVE");
        assertThat(result.get("cancelAtPeriodEnd")).isEqualTo(false);
    }

    @Test
    void aPastDueSubscriptionIsRetriedTheNextDayAndRenewedWhenTheChargeNowSucceeds() {
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-retry-ok-" + java.util.UUID.randomUUID()
                + "@example.com");
        Instant originalPeriodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());

        declineRenewalCharges(owner, 1);
        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.renewDueSubscriptions();
        assertThat(getMine(owner).get("status")).isEqualTo("PAST_DUE");

        // The same day: nothing to retry yet (the failure above just happened).
        subscriptionRenewalService.retryPastDueSubscriptions();
        assertThat(getMine(owner).get("status")).isEqualTo("PAST_DUE");

        clock.advanceTo(clock.instant().plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.retryPastDueSubscriptions();

        Map<?, ?> renewed = getMine(owner);
        assertThat(renewed.get("plan")).isEqualTo("PRO");
        assertThat(renewed.get("status")).isEqualTo("ACTIVE");
        assertThat(renewed.get("gracePeriodEndsAt")).isNull();
        assertThat(Instant.parse(renewed.get("currentPeriodEnd").toString())).isAfter(originalPeriodEnd);
    }

    @Test
    void aFailedRetryKeepsTheOriginalGraceWindowAndEachDayGetsExactlyOneAttempt() {
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-retry-fail-" + java.util.UUID.randomUUID()
                + "@example.com");
        Instant originalPeriodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());

        declineRenewalCharges(owner, 2);
        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.renewDueSubscriptions();
        Instant graceEndsAt = Instant.parse(getMine(owner).get("gracePeriodEndsAt").toString());
        java.util.UUID failedChargeId = latestChargeId(owner);
        assertThat(failureController.chargeAttempts.get(failedChargeId).get()).isEqualTo(1);

        // Same day: skipped, still one attempt.
        subscriptionRenewalService.retryPastDueSubscriptions();
        assertThat(failureController.chargeAttempts.get(failedChargeId).get()).isEqualTo(1);

        // Next day: one more attempt, which fails again (the second queued decline).
        clock.advanceTo(clock.instant().plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.retryPastDueSubscriptions();
        subscriptionRenewalService.retryPastDueSubscriptions();

        assertThat(failureController.chargeAttempts.get(failedChargeId).get()).isEqualTo(2);
        Map<?, ?> stillPastDue = getMine(owner);
        assertThat(stillPastDue.get("status")).isEqualTo("PAST_DUE");
        assertThat(Instant.parse(stillPastDue.get("gracePeriodEndsAt").toString())).isEqualTo(graceEndsAt);
    }

    @Test
    void aRetryIsNotMadeOnceTheGracePeriodHasExpired() {
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-retry-expired-" + java.util.UUID.randomUUID()
                + "@example.com");
        Instant originalPeriodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());

        declineRenewalCharges(owner, 1);
        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));
        subscriptionRenewalService.renewDueSubscriptions();
        java.util.UUID failedChargeId = latestChargeId(owner);

        clock.advanceTo(clock.instant().plus(8, ChronoUnit.DAYS));
        subscriptionRenewalService.retryPastDueSubscriptions();
        assertThat(failureController.chargeAttempts.get(failedChargeId).get()).isEqualTo(1);

        subscriptionRenewalService.downgradeExpiredGracePeriods();
        assertThat(getMine(owner).get("plan")).isEqualTo("FREE");
    }

    @Test
    void twoOverlappingRenewalRunsChargeADueSubscriptionOnlyOnce() throws Exception {
        Registered owner = TestAuth.registerOwner(restTemplate, "renewal-concurrent-" + java.util.UUID.randomUUID()
                + "@example.com");
        Instant originalPeriodEnd = Instant.parse(upgrade(owner).get("currentPeriodEnd").toString());
        clock.advanceTo(originalPeriodEnd.plus(1, ChronoUnit.DAYS));

        var pool = java.util.concurrent.Executors.newFixedThreadPool(2);
        var startTogether = new java.util.concurrent.CountDownLatch(1);
        try {
            var runs = java.util.List.of(
                    pool.submit(() -> {
                        startTogether.await();
                        subscriptionRenewalService.renewDueSubscriptions();
                        return null;
                    }),
                    pool.submit(() -> {
                        startTogether.await();
                        subscriptionRenewalService.renewDueSubscriptions();
                        return null;
                    }));
            startTogether.countDown();
            for (var run : runs) {
                run.get(60, java.util.concurrent.TimeUnit.SECONDS);
            }
        } finally {
            pool.shutdownNow();
        }

        // The upgrade charge plus exactly one renewal charge, attempted once.
        java.util.List<?> charges = charges(owner);
        assertThat(charges).hasSize(2);
        java.util.UUID renewalChargeId = latestChargeId(owner);
        assertThat(failureController.chargeAttempts.get(renewalChargeId).get()).isEqualTo(1);
        assertThat(getMine(owner).get("status")).isEqualTo("ACTIVE");
    }

    private java.util.List<?> charges(Registered owner) {
        ResponseEntity<java.util.List> response = restTemplate.exchange("/api/v1/subscriptions/me/charges",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())),
                java.util.List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    /** The charge list is most-recent-first. */
    private java.util.UUID latestChargeId(Registered owner) {
        return java.util.UUID.fromString(((Map<?, ?>) charges(owner).get(0)).get("id").toString());
    }

    /**
     * Declines the next {@code times} renewal charges of this owner's subscription only. Right after the upgrade
     * the owner has exactly one charge, whose id is the mock recurring profile's.
     */
    private void declineRenewalCharges(Registered owner, int times) {
        String profileId = "mock_recurring_" + latestChargeId(owner);
        failureController.declineRecurringByProfile.put(profileId, new java.util.concurrent.atomic.AtomicInteger(times));
    }

    private Map<?, ?> getMine(Registered owner) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/subscriptions/me", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private Map<?, ?> upgrade(Registered owner) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/subscriptions/upgrade", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private Map<?, ?> downgrade(Registered owner) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/subscriptions/downgrade", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }
}
