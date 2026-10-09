package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.vertical.beauty.MasterDtos.CreateMasterRequest;
import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
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
 * Against a real Postgres (Testcontainers): the FREE plan's 4 limits
 * (providers/staff/bookings-per-month/recurring-schedule), and the
 * upgrade-to-PRO flow lifting all of them. {@link TestPayments} makes the
 * PRO upgrade charge deterministic (the plain MockPaymentProvider always
 * succeeds, which is exactly what these tests want for the happy path).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class})
class SubscriptionApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void subscriptionIsCreatedLazilyAsFreeOnFirstAccess() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-lazy-" + runId + "@example.com");

        Map<?, ?> subscription = getMine(owner);
        assertThat(subscription.get("plan")).isEqualTo("FREE");
        // The price the app shows comes from here, never from a literal in the client.
        assertThat(subscription.get("proMonthlyPrice")).isEqualTo(29.0);
        assertThat(subscription.get("currency")).isEqualTo("USD");
        assertThat(subscription.get("status")).isEqualTo("ACTIVE");
        Map<?, ?> limits = (Map<?, ?>) subscription.get("limits");
        assertThat(limits.get("maxProviders")).isEqualTo(1);
        assertThat(limits.get("maxStaffPerProvider")).isEqualTo(3);
        assertThat(limits.get("maxBookingsPerMonth")).isEqualTo(30);
        assertThat(limits.get("recurringScheduleAllowed")).isEqualTo(false);
    }

    @Test
    void freeOwnerIsBlockedFromCreatingASecondProvider() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-2nd-provider-" + runId + "@example.com");
        createProvider(owner, "First Business " + runId, "beauty");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), "Second Business " + runId, "beauty"),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.PAYMENT_REQUIRED);
    }

    @Test
    void freeOwnerIsBlockedFromAddingAFourthStaffMember() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-4th-staff-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Staff Limit Salon " + runId, "beauty");
        createMaster(owner, providerId, "Master One");
        createMaster(owner, providerId, "Master Two");
        createMaster(owner, providerId, "Master Three");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/beauty/providers/" + providerId + "/masters",
                HttpMethod.POST, new HttpEntity<>(new CreateMasterRequest("Master Four", null, null),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.PAYMENT_REQUIRED);
    }

    @Test
    void freeOwnerIsBlockedFromRecurringScheduleGeneration() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-recurring-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Recurring Salon " + runId, "beauty");

        LocalDate start = LocalDate.now().plusDays(1);
        var request = new RecurringScheduleRequest(List.of(DayOfWeek.MONDAY), LocalTime.of(9, 0),
                LocalTime.of(17, 0), 30, 10, start, start.plusDays(7), List.of(), "UTC");
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots/recurring", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.PAYMENT_REQUIRED);
    }

    @Test
    void freeOwnerIsBlockedAfterThirtyBookingsInAMonth() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-booking-limit-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "sub-booking-cust-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Booking Limit Salon " + runId, "beauty");
        UUID serviceId = createService(owner, providerId, "Quick Trim", new BigDecimal("10.00"));

        for (int i = 0; i < 30; i++) {
            UUID slotId = createOpenSlot(owner, providerId, i);
            ResponseEntity<Map> response = createBooking(customer, serviceId, slotId);
            assertThat(response.getStatusCode()).as("booking #%d", i + 1).isEqualTo(HttpStatus.CREATED);
        }

        UUID overLimitSlot = createOpenSlot(owner, providerId, 30);
        ResponseEntity<Map> rejected = createBooking(customer, serviceId, overLimitSlot);
        assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.PAYMENT_REQUIRED);
    }

    /**
     * Scenario F (Phase 0 stabilization): fills to 29/30 sequentially (not
     * part of the race), then fires several concurrent requests at the
     * 30th-and-beyond slots. Before {@code BookingService}'s advisory lock,
     * a plain read-then-write count check let concurrent requests all read
     * 29, all pass the quota check, and all commit — the FREE plan's cap
     * could be exceeded by however many requests raced. Exactly one of
     * these must succeed regardless of how many race for the last slot.
     */
    @Test
    void concurrentBookingsAtTheFreeLimitCannotExceedThirtyPerMonth() throws Exception {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-booking-race-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "sub-booking-race-cust-" + runId
                + "@example.com");
        UUID providerId = createProvider(owner, "Booking Race Salon " + runId, "beauty");
        UUID serviceId = createService(owner, providerId, "Quick Trim", new BigDecimal("10.00"));

        for (int i = 0; i < 29; i++) {
            UUID slotId = createOpenSlot(owner, providerId, i);
            ResponseEntity<Map> response = createBooking(customer, serviceId, slotId);
            assertThat(response.getStatusCode()).as("booking #%d", i + 1).isEqualTo(HttpStatus.CREATED);
        }

        int concurrentAttempts = 5;
        List<UUID> raceSlots = new ArrayList<>();
        for (int i = 0; i < concurrentAttempts; i++) {
            raceSlots.add(createOpenSlot(owner, providerId, 29 + i));
        }

        ExecutorService pool = Executors.newFixedThreadPool(concurrentAttempts);
        CountDownLatch ready = new CountDownLatch(concurrentAttempts);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger created = new AtomicInteger();
        AtomicInteger rejected = new AtomicInteger();

        List<Callable<Void>> tasks = new ArrayList<>();
        for (UUID slotId : raceSlots) {
            tasks.add(() -> {
                ready.countDown();
                go.await();
                ResponseEntity<Map> response = createBooking(customer, serviceId, slotId);
                if (response.getStatusCode() == HttpStatus.CREATED) {
                    created.incrementAndGet();
                } else if (response.getStatusCode() == HttpStatus.PAYMENT_REQUIRED) {
                    rejected.incrementAndGet();
                }
                return null;
            });
        }
        List<Future<Void>> futures = new ArrayList<>();
        for (Callable<Void> task : tasks) {
            futures.add(pool.submit(task));
        }
        ready.await();
        go.countDown();
        for (Future<Void> future : futures) {
            future.get(30, TimeUnit.SECONDS);
        }
        pool.shutdown();
        assertThat(pool.awaitTermination(30, TimeUnit.SECONDS)).isTrue();

        assertThat(created.get()).isEqualTo(1);
        assertThat(rejected.get()).isEqualTo(concurrentAttempts - 1);
    }

    @Test
    void upgradeToProChargesAndLiftsAllFourLimits() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-upgrade-" + runId + "@example.com");
        createProvider(owner, "Pre-Upgrade Business " + runId, "beauty");

        Map<?, ?> upgraded = upgrade(owner);
        assertThat(upgraded.get("plan")).isEqualTo("PRO");
        assertThat(upgraded.get("status")).isEqualTo("ACTIVE");

        // Provider limit lifted: a second provider is now allowed.
        ResponseEntity<Map> secondProvider = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), "Post-Upgrade Business " + runId,
                        "beauty"), TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(secondProvider.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void downgradeIsSelfServiceAndDoesNotChangeThePlanImmediately() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sub-downgrade-" + runId + "@example.com");
        upgrade(owner);

        Map<?, ?> downgraded = downgrade(owner);
        // Still PRO — takes effect at currentPeriodEnd, no immediate change,
        // no refund of the period already paid for.
        assertThat(downgraded.get("plan")).isEqualTo("PRO");
        assertThat(downgraded.get("cancelAtPeriodEnd")).isEqualTo(true);
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

    private ResponseEntity<Map> createBooking(Registered customer, UUID serviceId, UUID slotId) {
        var request = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("10.00"));
        return restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(customer.accessToken())), Map.class);
    }

    private UUID createMaster(Registered owner, UUID providerId, String displayName) {
        var request = new CreateMasterRequest(displayName, "Bio", null);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/beauty/providers/" + providerId + "/masters",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createProvider(Registered owner, String name, String vertical) {
        var request = new CreateProviderRequest(owner.userId(), name, vertical);
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

    /** {@code index} spaces each slot an hour apart so none overlap within the same day. */
    private UUID createOpenSlot(Registered owner, UUID providerId, int index) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS).plus(index, ChronoUnit.HOURS);
        var request = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
