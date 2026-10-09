package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.vertical.beauty.BeautyBookingDtos.CreateBeautyBookingRequest;
import com.zairo.factory.vertical.beauty.MasterDtos.AddPortfolioItemRequest;
import com.zairo.factory.vertical.beauty.MasterDtos.CreateMasterRequest;
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

/** Against a real Postgres (Testcontainers): master directory, portfolio, master-service linking, and the beauty booking rule. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class BeautyApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void rejectsMasterCreationOnANonBeautyProvider() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "non-beauty-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Quick Lube " + runId, "auto-" + runId);

        // Same owner/token as the provider, so this exercises the vertical
        // check (400), not the ownership check (403) — see createMaster's
        // check order: 404 provider -> 403 ownership -> 400 vertical.
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/beauty/providers/" + providerId + "/masters",
                HttpMethod.POST, new HttpEntity<>(new CreateMasterRequest("Someone", null, null),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    /**
     * Provider.vertical is free, unvalidated text (Core never checks it) —
     * a real owner could easily type "Beauty" or " beauty " when creating
     * their salon. This proves the vertical check tolerates that instead of
     * silently, confusingly rejecting a genuinely-beauty provider — and,
     * together with the test above, that the check is driven by one
     * explicit comparison in vertical-beauty, not some assumption Core
     * makes about the string "beauty" (Core makes none — see
     * providers.Provider's own doc comment).
     */
    @Test
    void acceptsMasterCreationRegardlessOfVerticalCasingOrWhitespace() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cased-vertical-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Cased Vertical Salon " + runId, " Beauty ");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/beauty/providers/" + providerId + "/masters",
                HttpMethod.POST, new HttpEntity<>(new CreateMasterRequest("Someone", null, null),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void fullMasterDirectoryAndBookingFlow() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "beauty-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "beauty-customer-" + runId + "@example.com");
        UUID customerId = customer.userId();
        // Case/whitespace-normalized but still an exact vertical match, not
        // a prefix match — see MasterDirectoryService.isBeautyVertical.
        UUID providerId = createProvider(owner, "Glow Salon " + runId, "beauty");
        UUID serviceId = createService(owner, providerId, "Balayage", new BigDecimal("120.00"));

        UUID masterId = createMaster(owner, providerId, "Jamie Stylist");
        assertThat(masterId).isNotNull();

        // Portfolio — owner-only.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/portfolio", HttpMethod.POST,
                new HttpEntity<>(new AddPortfolioItemRequest("https://example.com/photo1.jpg", "Balayage look"),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        List<Map> portfolio = getList("/api/v1/beauty/masters/" + masterId + "/portfolio");
        assertThat(portfolio).hasSize(1);
        assertThat(portfolio.get(0).get("caption")).isEqualTo("Balayage look");

        // Booking rule: master hasn't been linked to the service yet -> 409.
        UUID slotId = createOpenSlot(owner, providerId);
        ResponseEntity<Map> rejected = restTemplate.exchange("/api/v1/beauty/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateBeautyBookingRequest(customerId, masterId, serviceId, slotId,
                                new BigDecimal("120.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Link master <-> service (owner-only), confirm it shows up.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        List<Map> services = getList("/api/v1/beauty/masters/" + masterId + "/services");
        assertThat(services).extracting(s -> s.get("serviceId")).containsExactly(serviceId.toString());
        // Idempotent: linking again doesn't duplicate.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/beauty/masters/" + masterId + "/services")).hasSize(1);

        // Now the booking succeeds.
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/beauty/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateBeautyBookingRequest(customerId, masterId, serviceId, slotId,
                                new BigDecimal("120.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String bookingId = created.getBody().get("bookingId").toString();
        assertThat(created.getBody().get("masterId")).isEqualTo(masterId.toString());
        // Not CONFIRMED yet — a booking starts PENDING_PAYMENT until its payment succeeds (ADR-0006).
        assertThat(created.getBody().get("status")).isEqualTo("PENDING_PAYMENT");

        // Fetching it back through the beauty endpoint (as its own customer) returns the same master link.
        Map<?, ?> fetched = restTemplate.exchange("/api/v1/beauty/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        assertThat(fetched.get("masterId")).isEqualTo(masterId.toString());

        // Unlink (owner-only) is idempotent too.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/beauty/masters/" + masterId + "/services")).isEmpty();
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
    }

    @Test
    void deactivatingAMasterRemovesItFromTheProviderListingAndReactivationBringsItBack() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "deactivate-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Deactivate Salon " + runId, "beauty");
        UUID masterId = createMaster(owner, providerId, "Temp Master");

        assertThat(getList("/api/v1/beauty/providers/" + providerId + "/masters")).extracting(m -> m.get("id"))
                .containsExactly(masterId.toString());

        // A different owner can't deactivate someone else's master — 403.
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "deactivate-other-owner-" + runId
                + "@example.com");
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/beauty/masters/" + masterId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())),
                Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deactivateResponse = restTemplate.exchange("/api/v1/beauty/masters/" + masterId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        assertThat(getList("/api/v1/beauty/providers/" + providerId + "/masters")).isEmpty();

        // Deactivating again (or a non-existent id) is a no-op, not an error.
        ResponseEntity<Void> deactivateAgain = restTemplate.exchange("/api/v1/beauty/masters/" + masterId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // Still invisible by default, but visible with includeInactive=true.
        assertThat(getList("/api/v1/beauty/providers/" + providerId + "/masters?includeInactive=true"))
                .extracting(m -> m.get("id")).containsExactly(masterId.toString());

        ResponseEntity<Map> reactivateResponse = restTemplate.exchange(
                "/api/v1/beauty/masters/" + masterId + "/reactivate", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(reactivateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reactivateResponse.getBody().get("active")).isEqualTo(true);
        assertThat(getList("/api/v1/beauty/providers/" + providerId + "/masters")).extracting(m -> m.get("id"))
                .containsExactly(masterId.toString());
    }

    /**
     * Proves the fix for GET /beauty/bookings/{id}'s missing auth/ownership
     * check (Security Audit #4, P0-NEW-1): only the booking's own customer
     * or its provider's own owner may read it — a stranger (customer or
     * unrelated provider owner) gets 403, and no token at all gets 401, same
     * pattern as core BookingController.getById (PR #57).
     */
    @Test
    void gettingABeautyBookingRequiresBeingItsCustomerOrItsProvidersOwner() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "beauty-get-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "beauty-get-other-owner-" + runId
                + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "beauty-get-customer-" + runId
                + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "beauty-get-other-customer-" + runId
                + "@example.com");

        UUID providerId = createProvider(owner, "Get Salon " + runId, "beauty");
        UUID serviceId = createService(owner, providerId, "Get Service", new BigDecimal("50.00"));
        UUID masterId = createMaster(owner, providerId, "Get Master");
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        UUID slotId = createOpenSlot(owner, providerId);

        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/beauty/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateBeautyBookingRequest(customer.userId(), masterId, serviceId, slotId,
                                new BigDecimal("50.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(created.getBody().get("bookingId").toString());

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/beauty/bookings/" + bookingId,
                Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The booking's own customer can read it.
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/beauty/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The provider's own owner can read it too.
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/beauty/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.OK);

        // A different customer cannot.
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/beauty/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different provider's owner cannot either.
        ResponseEntity<Map> asOtherOwner = restTemplate.exchange("/api/v1/beauty/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(asOtherOwner.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    private List<Map> getList(String path) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(path, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private UUID createMaster(Registered owner, UUID providerId, String displayName) {
        var request = new CreateMasterRequest(displayName, "Bio", null);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/beauty/providers/" + providerId + "/masters",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    @Test
    void employeeScopedSlotsAreIndependentlyBookableAndCantBeClaimedByADifferentMaster() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "emp-slot-owner-" + runId + "@example.com");
        Registered customerA = TestAuth.registerCustomer(restTemplate, "emp-slot-cust-a-" + runId + "@example.com");
        Registered customerB = TestAuth.registerCustomer(restTemplate, "emp-slot-cust-b-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Multi Master Salon " + runId, "beauty");
        UUID serviceId = createService(owner, providerId, "Cut", new BigDecimal("20.00"));

        UUID masterA = createMaster(owner, providerId, "Master A");
        UUID masterB = createMaster(owner, providerId, "Master B");
        restTemplate.exchange("/api/v1/beauty/masters/" + masterA + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        restTemplate.exchange("/api/v1/beauty/masters/" + masterB + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);

        // Same exact time window, one slot per master — this is the whole
        // point: two employees, two independently bookable slots.
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotA = createEmployeeSlot(owner, providerId, masterA, start, start.plus(60, ChronoUnit.MINUTES));
        UUID slotB = createEmployeeSlot(owner, providerId, masterB, start, start.plus(60, ChronoUnit.MINUTES));

        // Master A's slot can't be claimed under Master B's name.
        ResponseEntity<Map> mismatched = restTemplate.exchange("/api/v1/beauty/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateBeautyBookingRequest(customerA.userId(), masterB, serviceId, slotA,
                        new BigDecimal("20.00")), TestAuth.authHeaders(customerA.accessToken())), Map.class);
        assertThat(mismatched.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Both customers book the same time window, one with each master —
        // both succeed, because they claimed two different slot rows.
        ResponseEntity<Map> bookedA = restTemplate.exchange("/api/v1/beauty/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateBeautyBookingRequest(customerA.userId(), masterA, serviceId, slotA,
                        new BigDecimal("20.00")), TestAuth.authHeaders(customerA.accessToken())), Map.class);
        assertThat(bookedA.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<Map> bookedB = restTemplate.exchange("/api/v1/beauty/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateBeautyBookingRequest(customerB.userId(), masterB, serviceId, slotB,
                        new BigDecimal("20.00")), TestAuth.authHeaders(customerB.accessToken())), Map.class);
        assertThat(bookedB.getStatusCode()).isEqualTo(HttpStatus.CREATED);
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
        UUID providerId = UUID.fromString(response.getBody().get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        return providerId;
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
