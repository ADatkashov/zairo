package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.staff.StaffBookingDtos.CreateStaffBookingRequest;
import com.zairo.factory.staff.StaffDtos.CreateStaffRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;
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
 * The customer never gets a person who can't serve them: no double booking of one human across businesses, no
 * booking while off or outside their own schedule, owner-controlled choice of person, and "any master".
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class WorkerAvailabilityApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    private static Instant tomorrowAt(int hour) {
        return LocalDate.now(ZoneOffset.UTC).plusDays(1).atTime(hour, 0).toInstant(ZoneOffset.UTC);
    }

    @Test
    void oneHumanCannotBeSoldTwiceForTheSameTimeAcrossBusinessesButMayWorkInBoth() {
        String runId = UUID.randomUUID().toString();
        Registered ownerA = TestAuth.registerOwner(restTemplate, "av-owner-a-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "av-owner-b-" + runId + "@example.com");
        Registered person = TestAuth.registerCustomer(restTemplate, "av-person-" + runId + "@example.com");
        Registered customer1 = TestAuth.registerCustomer(restTemplate, "av-c1-" + runId + "@example.com");
        Registered customer2 = TestAuth.registerCustomer(restTemplate, "av-c2-" + runId + "@example.com");

        // The same human is a beauty master at A (before lunch) and generic staff at B.
        UUID providerA = createProvider(ownerA, "Beauty A " + runId, "beauty");
        UUID serviceA = createService(ownerA, providerA, "Manicure");
        UUID masterA = UUID.fromString(post("/api/v1/beauty/providers/" + providerA + "/masters/from-user", ownerA,
                Map.of("userId", person.userId().toString())).getBody().get("id").toString());
        post("/api/v1/beauty/masters/" + masterA + "/services/" + serviceA, ownerA, null);

        UUID providerB = createProvider(ownerB, "Fitness B " + runId, "sport_fitness");
        UUID serviceB = createService(ownerB, providerB, "Training");
        UUID staffB = UUID.fromString(post("/api/v1/providers/" + providerB + "/staff/from-user", ownerB,
                Map.of("userId", person.userId().toString())).getBody().get("id").toString());
        post("/api/v1/staff/" + staffB + "/services/" + serviceB, ownerB, null);

        // Both businesses have a shared slot at the same time, plus B has a later one.
        Instant ten = tomorrowAt(10);
        UUID slotA = createSlot(ownerA, providerA, ten);
        UUID slotB = createSlot(ownerB, providerB, ten);
        UUID slotBLater = createSlot(ownerB, providerB, tomorrowAt(15));

        // Both businesses offer that time for the person.
        assertThat(availableStarts(providerA, masterA)).contains(ten);
        assertThat(availableStarts(providerB, staffB)).contains(ten);

        // A customer books the person at A.
        ResponseEntity<Map> booked = post("/api/v1/beauty/bookings", customer1,
                Map.of("userId", customer1.userId().toString(), "masterId", masterA.toString(),
                        "serviceId", serviceA.toString(), "availabilitySlotId", slotA.toString(), "totalPrice", 25));
        assertThat(booked.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // Now B no longer offers that minute for the same person — and refuses it if asked directly.
        assertThat(availableStarts(providerB, staffB)).doesNotContain(ten).contains(tomorrowAt(15));
        assertThat(restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customer2.userId(), staffB, serviceB, slotB,
                        new BigDecimal("40.00")), TestAuth.authHeaders(customer2.accessToken())), Map.class)
                .getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // But working at both is fine: the later slot at B is bookable.
        assertThat(restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customer2.userId(), staffB, serviceB, slotBLater,
                        new BigDecimal("40.00")), TestAuth.authHeaders(customer2.accessToken())), Map.class)
                .getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void aPersonOnTimeOffOrWithTheirOwnScheduleCannotBeBookedOnSharedSlots() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "off2-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "off2-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Guard Salon " + runId, "sport_fitness");
        UUID serviceId = createService(owner, providerId, "Cut");
        UUID off = createStaff(owner, providerId, "Off Person");
        UUID scheduled = createStaff(owner, providerId, "Scheduled Person");
        for (UUID staff : List.of(off, scheduled)) {
            post("/api/v1/staff/" + staff + "/services/" + serviceId, owner, null);
        }
        UUID shared = createSlot(owner, providerId, tomorrowAt(11));
        assertThat(availableStarts(providerId, off)).contains(tomorrowAt(11));

        // On time off: the shared slot disappears from their times and booking it is refused.
        post("/api/v1/providers/" + providerId + "/workers/" + off + "/time-off", owner,
                Map.of("startsAt", tomorrowAt(0).toString(), "endsAt", tomorrowAt(23).toString(), "reason", "Away"));
        assertThat(availableStarts(providerId, off)).doesNotContain(tomorrowAt(11));
        assertThat(bookStaff(customer, off, serviceId, shared)).isEqualTo(HttpStatus.CONFLICT);

        // With their own schedule, the shared slots are no longer theirs.
        restTemplate.exchange("/api/v1/providers/" + providerId + "/workers/" + scheduled + "/schedule",
                HttpMethod.PUT, new HttpEntity<>(Map.of("zoneId", "UTC", "slotMinutes", 60, "breakMinutes", 0,
                        "hours", List.of(Map.of("dayOfWeek", 1, "startTime", "09:00:00", "endTime", "10:00:00"))),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(availableStarts(providerId, scheduled)).doesNotContain(tomorrowAt(11));
        assertThat(bookStaff(customer, scheduled, serviceId, shared)).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void theOwnerControlsWhetherCustomersMayChooseAPerson() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "choice-owner-" + runId + "@example.com");
        Registered stranger = TestAuth.registerOwner(restTemplate, "choice-stranger-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "choice-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Choice Salon " + runId, "sport_fitness");
        UUID serviceId = createService(owner, providerId, "Cut");
        UUID staff = createStaff(owner, providerId, "Chosen One");
        post("/api/v1/staff/" + staff + "/services/" + serviceId, owner, null);
        UUID slot = createSlot(owner, providerId, tomorrowAt(12));

        // Default: choice is allowed, no per-person prices.
        Map<?, ?> defaults = restTemplate.getForEntity("/api/v1/providers/" + providerId + "/workforce-settings",
                Map.class).getBody();
        assertThat(defaults.get("allowWorkerChoice")).isEqualTo(true);
        assertThat(defaults.get("workerPricingEnabled")).isEqualTo(false);
        assertThat(availableStarts(providerId, staff)).contains(tomorrowAt(12));

        // Only the owner may change it.
        Map<String, Object> off = Map.of("allowWorkerChoice", false, "workerPricingEnabled", false);
        assertThat(restTemplate.exchange("/api/v1/providers/" + providerId + "/workforce-settings", HttpMethod.PUT,
                new HttpEntity<>(off, TestAuth.authHeaders(stranger.accessToken())), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange("/api/v1/providers/" + providerId + "/workforce-settings", HttpMethod.PUT,
                new HttpEntity<>(off, TestAuth.authHeaders(owner.accessToken())), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.OK);

        // Choice off: no per-person times, and asking for a person directly is refused...
        assertThat(availableStarts(providerId, staff)).isEmpty();
        assertThat(bookStaff(customer, staff, serviceId, slot)).isEqualTo(HttpStatus.CONFLICT);

        // ...but "any master" still books (the system picks the person).
        ResponseEntity<Map> any = post("/api/v1/providers/" + providerId + "/bookings/any", customer,
                Map.of("userId", customer.userId().toString(), "serviceId", serviceId.toString(),
                        "startsAt", tomorrowAt(12).toString()));
        assertThat(any.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(any.getBody().get("workerId")).isEqualTo(staff.toString());
    }

    @Test
    void anyMasterAssignsTheLeastBusyFreePersonAndRunsOutWhenEveryoneIsTaken() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "any-owner-" + runId + "@example.com");
        Registered c1 = TestAuth.registerCustomer(restTemplate, "any-c1-" + runId + "@example.com");
        Registered c2 = TestAuth.registerCustomer(restTemplate, "any-c2-" + runId + "@example.com");
        Registered c3 = TestAuth.registerCustomer(restTemplate, "any-c3-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Any Salon " + runId, "sport_fitness");
        UUID serviceId = createService(owner, providerId, "Cut");
        UUID first = createStaff(owner, providerId, "Alpha");
        UUID second = createStaff(owner, providerId, "Beta");
        for (UUID staff : List.of(first, second)) {
            post("/api/v1/staff/" + staff + "/services/" + serviceId, owner, null);
            restTemplate.exchange("/api/v1/providers/" + providerId + "/workers/" + staff + "/schedule",
                    HttpMethod.PUT, new HttpEntity<>(Map.of("zoneId", "UTC", "slotMinutes", 60, "breakMinutes", 0,
                            "hours", java.util.stream.IntStream.rangeClosed(1, 7).mapToObj(d -> Map.of("dayOfWeek", d,
                                    "startTime", "09:00:00", "endTime", "12:00:00")).toList()),
                            TestAuth.authHeaders(owner.accessToken())), Map.class);
        }

        // The merged list shows each time once, even though two people have it.
        ResponseEntity<Map[]> times = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/availability/any?serviceId=" + serviceId, Map[].class);
        assertThat(times.getStatusCode()).isEqualTo(HttpStatus.OK);
        long tenCount = List.of(times.getBody()).stream()
                .filter(t -> Instant.parse(t.get("startsAt").toString()).equals(tomorrowAt(10))).count();
        assertThat(tenCount).isEqualTo(1);

        Map<String, String> request1 = Map.of("userId", c1.userId().toString(), "serviceId", serviceId.toString(),
                "startsAt", tomorrowAt(10).toString());
        ResponseEntity<Map> b1 = post("/api/v1/providers/" + providerId + "/bookings/any", c1, request1);
        ResponseEntity<Map> b2 = post("/api/v1/providers/" + providerId + "/bookings/any", c2,
                Map.of("userId", c2.userId().toString(), "serviceId", serviceId.toString(),
                        "startsAt", tomorrowAt(10).toString()));
        assertThat(b1.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(b2.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        // The second customer got the other person.
        assertThat(b1.getBody().get("workerId")).isNotEqualTo(b2.getBody().get("workerId"));

        // Everyone is taken at 10:00 now.
        assertThat(post("/api/v1/providers/" + providerId + "/bookings/any", c3,
                Map.of("userId", c3.userId().toString(), "serviceId", serviceId.toString(),
                        "startsAt", tomorrowAt(10).toString())).getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // One can't book "any master" in someone else's name.
        assertThat(post("/api/v1/providers/" + providerId + "/bookings/any", c3,
                Map.of("userId", c1.userId().toString(), "serviceId", serviceId.toString(),
                        "startsAt", tomorrowAt(11).toString())).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    // --- helpers ---

    private List<Instant> availableStarts(UUID providerId, UUID workerId) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/workers/" + workerId + "/availability", Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody()).stream().map(s -> Instant.parse(s.get("startsAt").toString())).toList();
    }

    private HttpStatus bookStaff(Registered customer, UUID staffId, UUID serviceId, UUID slotId) {
        return HttpStatus.valueOf(restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customer.userId(), staffId, serviceId, slotId,
                        new BigDecimal("25.00")), TestAuth.authHeaders(customer.accessToken())), Map.class)
                .getStatusCode().value());
    }

    private ResponseEntity<Map> post(String path, Registered as, Object body) {
        return restTemplate.exchange(path, HttpMethod.POST, new HttpEntity<>(body,
                TestAuth.authHeaders(as.accessToken())), Map.class);
    }

    private UUID createProvider(Registered owner, String name, String vertical) {
        ResponseEntity<Map> response = post("/api/v1/providers", owner,
                new CreateProviderRequest(owner.userId(), name, vertical));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createService(Registered owner, UUID providerId, String title) {
        ResponseEntity<Map> response = post("/api/v1/providers/" + providerId + "/services", owner,
                new CreateServiceRequest(title, 60, new BigDecimal("25.00"), "USD"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createStaff(Registered owner, UUID providerId, String name) {
        ResponseEntity<Map> response = post("/api/v1/providers/" + providerId + "/staff", owner,
                new CreateStaffRequest(name, "Bio", null));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createSlot(Registered owner, UUID providerId, Instant start) {
        ResponseEntity<Map> response = post("/api/v1/providers/" + providerId + "/availability-slots", owner,
                Map.of("startsAt", start.toString(), "endsAt", start.plusSeconds(3600).toString()));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
