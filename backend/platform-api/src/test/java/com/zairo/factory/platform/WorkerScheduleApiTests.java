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
import java.time.ZonedDateTime;
import java.util.ArrayList;
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

/** Owner-managed weekly schedule: generated slots, permissions, edits, time off, and a worker reporting sick. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class WorkerScheduleApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    private static List<Map<String, Object>> workingDays(String... intervals) {
        List<Map<String, Object>> hours = new ArrayList<>();
        for (int day = 1; day <= 7; day++) {
            for (int i = 0; i < intervals.length; i += 2) {
                hours.add(Map.of("dayOfWeek", day, "startTime", intervals[i], "endTime", intervals[i + 1]));
            }
        }
        return hours;
    }

    private static Map<String, Object> scheduleBody(List<Map<String, Object>> hours) {
        return Map.of("zoneId", "UTC", "slotMinutes", 60, "breakMinutes", 0, "hours", hours);
    }

    @Test
    void theOwnerSetsAWeeklyScheduleAndTheWorkerGetsTheirOwnSlots() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "sched-owner-" + runId + "@example.com");
        Registered stranger = TestAuth.registerOwner(restTemplate, "sched-stranger-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Schedule Salon " + runId);
        UUID otherProviderId = createProvider(stranger, "Other Salon " + runId);
        UUID staffId = createStaff(owner, providerId, "Aigerim");

        // No schedule yet: the worker uses the business's shared slots.
        Map<?, ?> none = get("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner);
        assertThat(none.get("configured")).isEqualTo(false);

        // Lunch is simply a gap between two intervals.
        var body = scheduleBody(workingDays("09:00:00", "13:00:00", "14:00:00", "18:00:00"));
        ResponseEntity<Map> saved = put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                body);
        assertThat(saved.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((Number) saved.getBody().get("slotsCreated")).intValue()).isGreaterThan(40);

        List<Map> slots = getSlots(providerId, staffId);
        assertThat(slots).isNotEmpty();
        for (Map slot : slots) {
            ZonedDateTime start = Instant.parse(slot.get("startsAt").toString()).atZone(ZoneOffset.UTC);
            assertThat(start.getHour()).isIn(9, 10, 11, 12, 14, 15, 16, 17);
            assertThat(start.getMinute()).isZero();
            assertThat(slot.get("status")).isEqualTo("OPEN");
        }

        // Saving the same schedule again changes nothing.
        ResponseEntity<Map> again = put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                body);
        assertThat(((Number) again.getBody().get("slotsCreated")).intValue()).isZero();
        assertThat(((Number) again.getBody().get("slotsRemoved")).intValue()).isZero();
        assertThat(getSlots(providerId, staffId)).hasSameSizeAs(slots);

        // Only the owner of THIS business: a stranger gets 403, and a worker of another business is not found.
        assertThat(put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", stranger, body)
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(put("/api/v1/providers/" + otherProviderId + "/workers/" + staffId + "/schedule", stranger, body)
                .getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Bad input is rejected: overlapping intervals, an unknown zone, and an interval that ends before it starts.
        assertThat(put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                scheduleBody(List.of(Map.of("dayOfWeek", 1, "startTime", "09:00:00", "endTime", "12:00:00"),
                        Map.of("dayOfWeek", 1, "startTime", "11:00:00", "endTime", "14:00:00"))))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                Map.of("zoneId", "Nowhere/Land", "slotMinutes", 60, "breakMinutes", 0,
                        "hours", workingDays("09:00:00", "10:00:00"))).getStatusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                scheduleBody(List.of(Map.of("dayOfWeek", 1, "startTime", "12:00:00", "endTime", "09:00:00"))))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // Changing the hours replaces the open slots; removing the schedule removes them too.
        put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                scheduleBody(workingDays("10:00:00", "12:00:00")));
        for (Map slot : getSlots(providerId, staffId)) {
            assertThat(Instant.parse(slot.get("startsAt").toString()).atZone(ZoneOffset.UTC).getHour())
                    .isIn(10, 11);
        }
        assertThat(restTemplate.exchange("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule",
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(getSlots(providerId, staffId)).isEmpty();
        assertThat(get("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner)
                .get("configured")).isEqualTo(false);
    }

    @Test
    void timeOffClosesNewBookingsButNeverCancelsExistingOnes() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "off-owner-" + runId + "@example.com");
        Registered worker = TestAuth.registerCustomer(restTemplate, "off-worker-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "off-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Off Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Cut");
        UUID staffId = addStaffFromUser(owner, providerId, worker.userId());
        restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                scheduleBody(workingDays("09:00:00", "17:00:00")));

        // Book tomorrow 10:00 (UTC) with the worker.
        LocalDate tomorrow = LocalDate.now(ZoneOffset.UTC).plusDays(1);
        Map<?, ?> slot = getSlots(providerId, staffId).stream()
                .filter(s -> Instant.parse(s.get("startsAt").toString()).atZone(ZoneOffset.UTC)
                        .toLocalDate().equals(tomorrow)
                        && Instant.parse(s.get("startsAt").toString()).atZone(ZoneOffset.UTC).getHour() == 10)
                .findFirst().orElseThrow();
        ResponseEntity<Map> booked = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customer.userId(), staffId, serviceId,
                        UUID.fromString(slot.get("id").toString()), new BigDecimal("25.00")),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(booked.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(booked.getBody().get("bookingId").toString());

        // The owner closes the whole of tomorrow: nothing is cancelled, the owner is told one booking is affected,
        // and no other slot of that day stays open.
        Instant from = tomorrow.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant to = tomorrow.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        ResponseEntity<Map> off = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/workers/" + staffId + "/time-off", HttpMethod.POST,
                new HttpEntity<>(Map.of("startsAt", from.toString(), "endsAt", to.toString(), "reason", "Sick"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(off.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(((Number) off.getBody().get("affectedAppointments")).intValue()).isEqualTo(1);
        UUID timeOffId = UUID.fromString(((Map<?, ?>) off.getBody().get("timeOff")).get("id").toString());

        assertThat(getSlots(providerId, staffId)).noneMatch(s -> "OPEN".equals(s.get("status"))
                && Instant.parse(s.get("startsAt").toString()).atZone(ZoneOffset.UTC).toLocalDate().equals(tomorrow));
        Map<?, ?> stillThere = restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        assertThat(stillThere.get("status")).isEqualTo("PENDING_PAYMENT");

        // The owner sees the worker is off; reopening brings the slots back.
        List<Map> workers = getList("/api/v1/providers/" + providerId + "/workers", owner);
        assertThat(workers).hasSize(1);
        assertThat(workers.get(0).get("scheduleConfigured")).isEqualTo(true);
        assertThat(restTemplate.exchange("/api/v1/providers/" + providerId + "/time-off/" + timeOffId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(getSlots(providerId, staffId)).anyMatch(s -> "OPEN".equals(s.get("status"))
                && Instant.parse(s.get("startsAt").toString()).atZone(ZoneOffset.UTC).toLocalDate().equals(tomorrow));
    }

    @Test
    void aWorkerCanOnlyReduceTheirOwnAvailability() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "self-owner-" + runId + "@example.com");
        Registered worker = TestAuth.registerCustomer(restTemplate, "self-worker-" + runId + "@example.com");
        Registered colleague = TestAuth.registerCustomer(restTemplate, "self-colleague-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Self Salon " + runId);
        UUID staffId = addStaffFromUser(owner, providerId, worker.userId());
        put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", owner,
                scheduleBody(workingDays("09:00:00", "17:00:00")));
        int before = getSlots(providerId, staffId).size();

        Instant from = Instant.now().plusSeconds(3600);
        Instant to = Instant.now().plusSeconds(3 * 86400);
        Map<String, String> period = Map.of("startsAt", from.toString(), "endsAt", to.toString(), "reason", "Sick");

        // Someone else's profile: forbidden.
        assertThat(restTemplate.exchange("/api/v1/me/staff/" + staffId + "/time-off", HttpMethod.POST,
                new HttpEntity<>(period, TestAuth.authHeaders(colleague.accessToken())), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);

        // Their own: allowed, and it closes slots straight away.
        ResponseEntity<Map> sick = restTemplate.exchange("/api/v1/me/staff/" + staffId + "/time-off",
                HttpMethod.POST, new HttpEntity<>(period, TestAuth.authHeaders(worker.accessToken())), Map.class);
        assertThat(sick.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(((Map<?, ?>) sick.getBody().get("timeOff")).get("byWorker")).isEqualTo(true);
        assertThat(getSlots(providerId, staffId).size()).isLessThan(before);

        // The worker cannot reopen it, change the schedule, or create a schedule: those are owner-only.
        UUID timeOffId = UUID.fromString(((Map<?, ?>) sick.getBody().get("timeOff")).get("id").toString());
        assertThat(restTemplate.exchange("/api/v1/providers/" + providerId + "/time-off/" + timeOffId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(worker.accessToken())), Void.class)
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(put("/api/v1/providers/" + providerId + "/workers/" + staffId + "/schedule", worker,
                scheduleBody(workingDays("00:00:00", "23:00:00"))).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    // --- helpers ---

    private List<Map> getSlots(UUID providerId, UUID employeeId) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/availability-slots?employeeId=" + employeeId, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private Map<?, ?> get(String path, Registered as) {
        ResponseEntity<Map> response = restTemplate.exchange(path, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private List<Map> getList(String path, Registered as) {
        ResponseEntity<Map[]> response = restTemplate.exchange(path, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private ResponseEntity<Map> put(String path, Registered as, Object body) {
        return restTemplate.exchange(path, HttpMethod.PUT, new HttpEntity<>(body,
                TestAuth.authHeaders(as.accessToken())), Map.class);
    }

    private UUID createProvider(Registered owner, String name) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), name, "sport_fitness"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString(response.getBody().get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        return providerId;
    }

    private UUID createService(Registered owner, UUID providerId, String title) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(new CreateServiceRequest(title, 60, new BigDecimal("25.00"), "USD"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createStaff(Registered owner, UUID providerId, String name) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/staff",
                HttpMethod.POST, new HttpEntity<>(new CreateStaffRequest(name, "Bio", null),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID addStaffFromUser(Registered owner, UUID providerId, UUID userId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/staff/from-user",
                HttpMethod.POST, new HttpEntity<>(Map.of("userId", userId.toString()),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
