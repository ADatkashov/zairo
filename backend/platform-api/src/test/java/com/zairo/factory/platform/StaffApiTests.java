package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.staff.StaffBookingDtos.CreateStaffBookingRequest;
import com.zairo.factory.staff.StaffDtos.CreateStaffRequest;
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
 * Against a real Postgres (Testcontainers): the generic staff directory and
 * staff booking rule — unlike {@link BeautyApiTests}, {@link AutoApiTests},
 * and cleaning's own equivalent, this module doesn't gate on the provider's
 * vertical at all, so any category (including a brand-new, purely
 * DB-defined one) can use it.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class StaffApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void worksForAProviderInAnyVerticalIncludingAnUnrecognizedOne() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "staff-owner-" + runId + "@example.com");
        // Not "beauty"/"auto"/"cleaning" — proves createStaff reads no
        // Provider.vertical at all, unlike the three hardcoded verticals.
        UUID providerId = createProvider(owner, "Dental Clinic " + runId, "medicine_dental");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/staff",
                HttpMethod.POST, new HttpEntity<>(new CreateStaffRequest("Dr. Aliya", null, null),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void fullStaffDirectoryAndBookingFlow() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "staff-full-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "staff-full-customer-" + runId
                + "@example.com");
        UUID customerId = customer.userId();
        UUID providerId = createProvider(owner, "Fitness Studio " + runId, "sport_fitness");
        UUID serviceId = createService(owner, providerId, "Personal training", new BigDecimal("40.00"));

        UUID staffId = createStaff(owner, providerId, "Coach Alex");
        assertThat(staffId).isNotNull();

        // Booking rule: staff member hasn't been linked to the service yet -> 409.
        UUID slotId = createOpenSlot(owner, providerId);
        ResponseEntity<Map> rejected = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateStaffBookingRequest(customerId, staffId, serviceId, slotId,
                                new BigDecimal("40.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Link staff <-> service (owner-only), confirm it shows up.
        restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        List<Map> services = getList("/api/v1/staff/" + staffId + "/services");
        assertThat(services).extracting(s -> s.get("serviceId")).containsExactly(serviceId.toString());
        // Idempotent: linking again doesn't duplicate.
        restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/staff/" + staffId + "/services")).hasSize(1);

        // Now the booking succeeds.
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateStaffBookingRequest(customerId, staffId, serviceId, slotId,
                                new BigDecimal("40.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String bookingId = created.getBody().get("bookingId").toString();
        assertThat(created.getBody().get("staffId")).isEqualTo(staffId.toString());
        assertThat(created.getBody().get("status")).isEqualTo("PENDING_PAYMENT");

        // Fetching it back through the staff endpoint (as its own customer) returns the same staff link.
        Map<?, ?> fetched = restTemplate.exchange("/api/v1/staff/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        assertThat(fetched.get("staffId")).isEqualTo(staffId.toString());

        // Unlink (owner-only) is idempotent too.
        restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/staff/" + staffId + "/services")).isEmpty();
        restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
    }

    @Test
    void deactivatingStaffRemovesThemFromTheProviderListingAndReactivationBringsThemBack() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "staff-deactivate-owner-" + runId
                + "@example.com");
        UUID providerId = createProvider(owner, "Law Office " + runId, "legal_" + runId);
        UUID staffId = createStaff(owner, providerId, "Temp Paralegal");

        assertThat(getList("/api/v1/providers/" + providerId + "/staff")).extracting(s -> s.get("id"))
                .containsExactly(staffId.toString());

        // A different owner can't deactivate someone else's staff — 403.
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "staff-deact-other-owner-" + runId
                + "@example.com");
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/staff/" + staffId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deactivateResponse = restTemplate.exchange("/api/v1/staff/" + staffId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        assertThat(getList("/api/v1/providers/" + providerId + "/staff")).isEmpty();

        // Deactivating again (or a non-existent id) is a no-op, not an error.
        ResponseEntity<Void> deactivateAgain = restTemplate.exchange("/api/v1/staff/" + staffId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // Still invisible by default, but visible with includeInactive=true.
        assertThat(getList("/api/v1/providers/" + providerId + "/staff?includeInactive=true"))
                .extracting(s -> s.get("id")).containsExactly(staffId.toString());

        ResponseEntity<Map> reactivateResponse = restTemplate.exchange(
                "/api/v1/staff/" + staffId + "/reactivate", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(reactivateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reactivateResponse.getBody().get("active")).isEqualTo(true);
        assertThat(getList("/api/v1/providers/" + providerId + "/staff")).extracting(s -> s.get("id"))
                .containsExactly(staffId.toString());
    }

    @Test
    void employeeScopedSlotsAreIndependentlyBookableAndCantBeClaimedByADifferentStaffMember() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "staff-emp-slot-owner-" + runId + "@example.com");
        Registered customerA = TestAuth.registerCustomer(restTemplate, "staff-emp-slot-cust-a-" + runId
                + "@example.com");
        Registered customerB = TestAuth.registerCustomer(restTemplate, "staff-emp-slot-cust-b-" + runId
                + "@example.com");
        UUID providerId = createProvider(owner, "Multi Staff Clinic " + runId, "medicine_" + runId);
        UUID serviceId = createService(owner, providerId, "Checkup", new BigDecimal("20.00"));

        UUID staffA = createStaff(owner, providerId, "Staff A");
        UUID staffB = createStaff(owner, providerId, "Staff B");
        restTemplate.exchange("/api/v1/staff/" + staffA + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        restTemplate.exchange("/api/v1/staff/" + staffB + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotA = createEmployeeSlot(owner, providerId, staffA, start, start.plus(60, ChronoUnit.MINUTES));
        UUID slotB = createEmployeeSlot(owner, providerId, staffB, start, start.plus(60, ChronoUnit.MINUTES));

        // Staff A's slot can't be claimed under Staff B's name.
        ResponseEntity<Map> mismatched = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customerA.userId(), staffB, serviceId, slotA,
                        new BigDecimal("20.00")), TestAuth.authHeaders(customerA.accessToken())), Map.class);
        assertThat(mismatched.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Both customers book the same time window, one with each staff member.
        ResponseEntity<Map> bookedA = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customerA.userId(), staffA, serviceId, slotA,
                        new BigDecimal("20.00")), TestAuth.authHeaders(customerA.accessToken())), Map.class);
        assertThat(bookedA.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<Map> bookedB = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customerB.userId(), staffB, serviceId, slotB,
                        new BigDecimal("20.00")), TestAuth.authHeaders(customerB.accessToken())), Map.class);
        assertThat(bookedB.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    /**
     * Proves the fix for GET /staff/bookings/{id}'s missing auth/ownership
     * check (Security Audit #4, P0-NEW-1): only the booking's own customer
     * or its provider's own owner may read it — a stranger (customer or
     * unrelated provider owner) gets 403, and no token at all gets 401, same
     * pattern as core BookingController.getById (PR #57).
     */
    @Test
    void gettingAStaffBookingRequiresBeingItsCustomerOrItsProvidersOwner() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "staff-get-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "staff-get-other-owner-" + runId
                + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "staff-get-customer-" + runId
                + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "staff-get-other-customer-" + runId
                + "@example.com");

        UUID providerId = createProvider(owner, "Get Studio " + runId, "sport_fitness");
        UUID serviceId = createService(owner, providerId, "Get Service", new BigDecimal("45.00"));
        UUID staffId = createStaff(owner, providerId, "Get Staff");
        restTemplate.exchange("/api/v1/staff/" + staffId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        UUID slotId = createOpenSlot(owner, providerId);

        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateStaffBookingRequest(customer.userId(), staffId, serviceId, slotId,
                                new BigDecimal("45.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(created.getBody().get("bookingId").toString());

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/staff/bookings/" + bookingId,
                Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The booking's own customer can read it.
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/staff/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The provider's own owner can read it too.
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/staff/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.OK);

        // A different customer cannot.
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/staff/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different provider's owner cannot either.
        ResponseEntity<Map> asOtherOwner = restTemplate.exchange("/api/v1/staff/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(asOtherOwner.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    private List<Map> getList(String path) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(path, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private UUID createStaff(Registered owner, UUID providerId, String displayName) {
        var request = new CreateStaffRequest(displayName, "Bio", null);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/staff",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createEmployeeSlot(Registered owner, UUID providerId, UUID employeeId, Instant startsAt,
            Instant endsAt) {
        var request = new CreateAvailabilitySlotRequest(startsAt, endsAt, employeeId);
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
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
        var request = new CreateServiceRequest(title, 60, price, "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createOpenSlot(Registered owner, UUID providerId) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var request = new CreateAvailabilitySlotRequest(start, start.plus(60, ChronoUnit.MINUTES));
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
