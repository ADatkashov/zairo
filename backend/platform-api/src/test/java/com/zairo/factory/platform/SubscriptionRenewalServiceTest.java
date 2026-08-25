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

        setNextChargeToFail();
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

        setNextChargeToFail();
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

    private void setNextChargeToFail() {
        failureController.failNextCharge = true;
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
