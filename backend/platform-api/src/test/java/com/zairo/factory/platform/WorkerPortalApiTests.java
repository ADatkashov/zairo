package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.staff.StaffBookingDtos.CreateStaffBookingRequest;
import com.zairo.factory.staff.StaffDtos.CreateStaffFromUserRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
 * A worker's cabinet: one person at two businesses (and in two different directories), own appointments only,
 * accept / complete / "can't attend", rating — and only the owner can cancel with a refund.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class WorkerPortalApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void aPersonWorkingAtTwoBusinessesSeesAndActsOnlyOnTheirOwnAppointments() {
        String runId = UUID.randomUUID().toString();
        Registered ownerA = TestAuth.registerOwner(restTemplate, "portal-owner-a-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "portal-owner-b-" + runId + "@example.com");
        Registered worker = TestAuth.registerCustomer(restTemplate, "portal-worker-" + runId + "@example.com");
        Registered colleague = TestAuth.registerCustomer(restTemplate, "portal-colleague-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "portal-customer-" + runId + "@example.com");

        UUID providerA = createProvider(ownerA, "Portal Salon A " + runId);
        UUID providerB = createProvider(ownerB, "Portal Salon B " + runId);
        UUID serviceA = createService(ownerA, providerA, "Cut");
        UUID staffA = addStaffFromUser(ownerA, providerA, worker.userId());
        UUID staffB = addStaffFromUser(ownerB, providerB, worker.userId());
        UUID colleagueStaff = addStaffFromUser(ownerA, providerA, colleague.userId());
        for (UUID staff : List.of(staffA, colleagueStaff)) {
            restTemplate.exchange("/api/v1/staff/" + staff + "/services/" + serviceA, HttpMethod.POST,
                    new HttpEntity<>(null, TestAuth.authHeaders(ownerA.accessToken())), Void.class);
        }

        // Both workplaces show up in the switcher.
        List<Map> memberships = getList("/api/v1/me/staff-memberships", worker);
        assertThat(memberships).extracting(m -> m.get("staffId"))
                .containsExactlyInAnyOrder(staffA.toString(), staffB.toString());

        UUID myBooking = bookConfirmed(ownerA, providerA, serviceA, staffA, customer);
        UUID colleaguesBooking = bookConfirmed(ownerA, providerA, serviceA, colleagueStaff, customer);

        // Only my appointment is listed, and it awaits acceptance.
        List<Map> mine = getList("/api/v1/me/staff/" + staffA + "/appointments", worker);
        assertThat(mine).hasSize(1);
        assertThat(mine.get(0).get("bookingId")).isEqualTo(myBooking.toString());
        assertThat(mine.get(0).get("canAccept")).isEqualTo(true);
        assertThat(getList("/api/v1/me/staff/" + staffB + "/appointments", worker)).isEmpty();
        assertThat(findMembership(worker, staffA).get("pendingCount")).isEqualTo(1);

        // Not my profile / not my booking.
        assertThat(post("/api/v1/me/staff/" + staffA + "/appointments/" + myBooking + "/accept", colleague)
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(post("/api/v1/me/staff/" + staffA + "/appointments/" + colleaguesBooking + "/complete", worker)
                .getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Accept clears the pending count; accepting again is a no-op.
        assertThat(post("/api/v1/me/staff/" + staffA + "/appointments/" + myBooking + "/accept", worker)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(post("/api/v1/me/staff/" + staffA + "/appointments/" + myBooking + "/accept", worker)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        Map<?, ?> accepted = getList("/api/v1/me/staff/" + staffA + "/appointments", worker).get(0);
        assertThat(accepted.get("staffConfirmedAt")).isNotNull();
        assertThat(accepted.get("canAccept")).isEqualTo(false);
        assertThat(findMembership(worker, staffA).get("pendingCount")).isEqualTo(0);

        // Complete, then the customer can review and the rating shows up in the cabinet.
        assertThat(post("/api/v1/me/staff/" + staffA + "/appointments/" + myBooking + "/complete", worker)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        ResponseEntity<Map> review = restTemplate.exchange("/api/v1/bookings/" + myBooking + "/reviews",
                HttpMethod.POST, new HttpEntity<>(Map.of("rating", 4, "comment", "Nice"),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(review.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        Map<?, ?> rating = restTemplate.exchange("/api/v1/me/staff/" + staffA + "/rating", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(worker.accessToken())), Map.class).getBody();
        assertThat(((Number) rating.get("averageRating")).doubleValue()).isEqualTo(4.0);
        assertThat(((Number) rating.get("reviewCount")).longValue()).isEqualTo(1);
        assertThat((List<?>) rating.get("reviews")).hasSize(1);

        // Staff can't cancel (and so can't refund): the old endpoint is gone, "can't attend" only informs the owner.
        assertThat(post("/api/v1/me/staff/" + colleagueStaff + "/appointments/" + colleaguesBooking + "/cancel",
                colleague).getStatusCode().is2xxSuccessful()).isFalse();
        assertThat(post("/api/v1/me/staff/" + colleagueStaff + "/appointments/" + colleaguesBooking
                + "/cannot-attend", worker).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(post("/api/v1/me/staff/" + colleagueStaff + "/appointments/" + colleaguesBooking
                + "/cannot-attend", colleague).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        // Idempotent.
        assertThat(post("/api/v1/me/staff/" + colleagueStaff + "/appointments/" + colleaguesBooking
                + "/cannot-attend", colleague).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // The booking is untouched: still CONFIRMED, no further action offered to the staff member.
        Map<?, ?> asked = getList("/api/v1/me/staff/" + colleagueStaff + "/appointments", colleague).get(0);
        assertThat(asked.get("status")).isEqualTo("CONFIRMED");
        assertThat(asked.get("staffDeclinedAt")).isNotNull();
        assertThat(asked.get("canDecline")).isEqualTo(false);
        assertThat(asked.get("canAccept")).isEqualTo(false);

        // The owner sees it, a stranger owner doesn't, and only the owner can cancel (refunding the customer).
        List<Map> needs = getList("/api/v1/providers/" + providerA + "/appointments/needs-attention", ownerA);
        assertThat(needs).hasSize(1);
        assertThat(needs.get(0).get("bookingId")).isEqualTo(colleaguesBooking.toString());
        assertThat(needs.get(0).get("reason")).isEqualTo("WORKER_CANNOT_ATTEND");
        assertThat(restTemplate.exchange("/api/v1/providers/" + providerA + "/appointments/needs-attention",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(ownerB.accessToken())), Map.class)
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        // Not the owner of that business: 403. Owner of another business, naming a foreign booking: 404.
        assertThat(post("/api/v1/providers/" + providerA + "/appointments/" + colleaguesBooking + "/cancel", ownerB)
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(post("/api/v1/providers/" + providerB + "/appointments/" + colleaguesBooking + "/cancel", ownerB)
                .getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(post("/api/v1/providers/" + providerA + "/appointments/" + colleaguesBooking + "/cancel",
                ownerA).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(getList("/api/v1/providers/" + providerA + "/appointments/needs-attention", ownerA)).isEmpty();
        assertThat(getList("/api/v1/me/staff/" + colleagueStaff + "/appointments", colleague).get(0).get("status"))
                .isEqualTo("CANCELLED");
    }

    @Test
    void aBeautyMasterGetsTheSameCabinetAsGenericStaff() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "portal-m-owner-" + runId + "@example.com");
        Registered masterUser = TestAuth.registerCustomer(restTemplate, "portal-m-master-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "portal-m-customer-" + runId + "@example.com");

        UUID providerId = createProviderOfVertical(owner, "Portal Beauty " + runId, "beauty");
        UUID serviceId = createService(owner, providerId, "Manicure");
        ResponseEntity<Map> masterResponse = restTemplate.exchange(
                "/api/v1/beauty/providers/" + providerId + "/masters/from-user", HttpMethod.POST,
                new HttpEntity<>(Map.of("userId", masterUser.userId().toString()),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(masterResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID masterId = UUID.fromString(masterResponse.getBody().get("id").toString());
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);

        // The master sees the business in their cabinet, labelled as a MASTER.
        List<Map> memberships = getList("/api/v1/me/staff-memberships", masterUser);
        assertThat(memberships).hasSize(1);
        assertThat(memberships.get(0).get("staffId")).isEqualTo(masterId.toString());
        assertThat(memberships.get(0).get("kind")).isEqualTo("MASTER");

        // A booking made through the beauty endpoint shows up in the master's cabinet.
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, null, start);
        ResponseEntity<Map> booked = restTemplate.exchange("/api/v1/beauty/bookings", HttpMethod.POST,
                new HttpEntity<>(Map.of("userId", customer.userId().toString(), "masterId", masterId.toString(),
                        "serviceId", serviceId.toString(), "availabilitySlotId", slotId.toString(),
                        "totalPrice", 25), TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(booked.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(booked.getBody().get("bookingId").toString());
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);

        List<Map> mine = getList("/api/v1/me/staff/" + masterId + "/appointments", masterUser);
        assertThat(mine).extracting(a -> a.get("bookingId")).containsExactly(bookingId.toString());
        assertThat(mine.get(0).get("canAccept")).isEqualTo(true);

        // "Can't attend" only informs the owner; it never cancels.
        assertThat(post("/api/v1/me/staff/" + masterId + "/appointments/" + bookingId + "/cannot-attend",
                masterUser).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(getList("/api/v1/me/staff/" + masterId + "/appointments", masterUser).get(0).get("status"))
                .isEqualTo("CONFIRMED");
        List<Map> needs = getList("/api/v1/providers/" + providerId + "/appointments/needs-attention", owner);
        assertThat(needs).hasSize(1);
        assertThat(needs.get(0).get("workerKind")).isEqualTo("MASTER");

        // Only the owner can cancel (and refund).
        assertThat(post("/api/v1/providers/" + providerId + "/appointments/" + bookingId + "/cancel", owner)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(getList("/api/v1/me/staff/" + masterId + "/appointments", masterUser).get(0).get("status"))
                .isEqualTo("CANCELLED");
    }

    // --- helpers ---

    private UUID bookConfirmed(Registered owner, UUID providerId, UUID serviceId, UUID staffId, Registered customer) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, staffId, start);
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customer.userId(), staffId, serviceId, slotId,
                        new BigDecimal("25.00")), TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(created.getBody().get("bookingId").toString());
        // Paying confirms the booking (ADR-0006).
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        return bookingId;
    }

    private ResponseEntity<Void> post(String path, Registered as) {
        return restTemplate.exchange(path, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Void.class);
    }

    private List<Map> getList(String path, Registered as) {
        ResponseEntity<Map[]> response = restTemplate.exchange(path, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private Map<?, ?> findMembership(Registered as, UUID staffId) {
        return getList("/api/v1/me/staff-memberships", as).stream()
                .filter(m -> staffId.toString().equals(m.get("staffId"))).findFirst().orElseThrow();
    }

    private UUID addStaffFromUser(Registered owner, UUID providerId, UUID userId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/staff/from-user",
                HttpMethod.POST, new HttpEntity<>(new CreateStaffFromUserRequest(userId),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createProvider(Registered owner, String name) {
        return createProviderOfVertical(owner, name, "sport_fitness");
    }

    private UUID createProviderOfVertical(Registered owner, String name, String vertical) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), name, vertical),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createService(Registered owner, UUID providerId, String title) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(new CreateServiceRequest(title, 60, new BigDecimal("25.00"), "USD"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createSlot(Registered owner, UUID providerId, UUID employeeId, Instant start) {
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(new CreateAvailabilitySlotRequest(start, start.plus(60, ChronoUnit.MINUTES),
                        employeeId), TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
