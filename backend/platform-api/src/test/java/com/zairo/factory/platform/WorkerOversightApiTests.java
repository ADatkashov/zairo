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
import com.zairo.factory.workforce.WorkerUnacceptedWarningService;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Oversight: the owner is warned about an upcoming appointment its worker hasn't accepted, and can correct a wrongly
 * marked no-show (but never reverse a completed visit).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class WorkerOversightApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private WorkerUnacceptedWarningService warningService;

    @Test
    void anAppointmentNotAcceptedShortlyBeforeTheVisitIsFlaggedOnceAndClearsWhenAccepted() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ovs-owner-" + runId + "@example.com");
        Registered worker = TestAuth.registerCustomer(restTemplate, "ovs-worker-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "ovs-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Oversight Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Cut");
        UUID staff = addStaffFromUser(owner, providerId, worker.userId());
        restTemplate.exchange("/api/v1/staff/" + staff + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        UUID booking = bookConfirmed(owner, providerId, serviceId, staff, customer);

        List<Map> needs = getList("/api/v1/providers/" + providerId + "/appointments/needs-attention", owner);
        assertThat(needs).hasSize(1);
        assertThat(needs.get(0).get("reason")).isEqualTo("WORKER_NOT_ACCEPTED");
        // Nothing to ask the customer about — the person may simply be about to accept.
        assertThat(post("/api/v1/providers/" + providerId + "/appointments/" + booking + "/ask-customer", owner)
                .getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // The warning goes out once.
        assertThat(warningService.warnDue(Instant.now())).isGreaterThanOrEqualTo(1);
        assertThat(warningService.warnDue(Instant.now())).isZero();

        assertThat(post("/api/v1/me/staff/" + staff + "/appointments/" + booking + "/accept", worker)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(getList("/api/v1/providers/" + providerId + "/appointments/needs-attention", owner)).isEmpty();
    }

    @Test
    void theOwnerCanCorrectAWrongNoShowButNotAFinishedVisit() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ovs2-owner-" + runId + "@example.com");
        Registered stranger = TestAuth.registerOwner(restTemplate, "ovs2-stranger-" + runId + "@example.com");
        Registered worker = TestAuth.registerCustomer(restTemplate, "ovs2-worker-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "ovs2-customer-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Oversight Salon 2 " + runId);
        UUID serviceId = createService(owner, providerId, "Cut");
        UUID staff = addStaffFromUser(owner, providerId, worker.userId());
        restTemplate.exchange("/api/v1/staff/" + staff + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        UUID wrong = bookConfirmed(owner, providerId, serviceId, staff, customer);
        String base = "/api/v1/providers/" + providerId + "/appointments/" + wrong;

        // Only a no-show can be corrected.
        assertThat(post(base + "/mark-attended", owner).getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(post("/api/v1/me/staff/" + staff + "/appointments/" + wrong + "/no-show", worker)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(status(owner, wrong)).isEqualTo("NO_SHOW");

        assertThat(post(base + "/mark-attended", stranger).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(post(base + "/mark-attended", owner).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(status(owner, wrong)).isEqualTo("COMPLETED");
        // A completed visit stays completed.
        assertThat(post(base + "/mark-attended", owner).getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    private String status(Registered as, UUID bookingId) {
        return restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Map.class).getBody()
                .get("status").toString();
    }

    // --- helpers ---

    private UUID bookConfirmed(Registered owner, UUID providerId, UUID serviceId, UUID staffId, Registered customer) {
        UUID slotId = createSlot(owner, providerId, staffId, Instant.now().plus(3, ChronoUnit.HOURS));
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
