package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.vertical.auto.AutoBookingDtos.CreateAutoBookingRequest;
import com.zairo.factory.vertical.auto.MechanicDtos.CreateMechanicRequest;
import com.zairo.factory.vertical.auto.VehicleDtos.CreateVehicleRequest;
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
 * Against a real Postgres (Testcontainers): mechanic directory,
 * mechanic-service linking, vehicle self-service ownership, and the auto
 * booking rules (mechanic must offer the service, vehicle must belong to
 * the booking's own user).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class AutoApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void rejectsMechanicCreationOnANonAutoProvider() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "non-auto-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Glow Salon " + runId, "beauty-" + runId);

        // Same owner/token as the provider, so this exercises the vertical
        // check (400), not the ownership check (403) — see createMechanic's
        // check order: 404 provider -> 403 ownership -> 400 vertical.
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auto/providers/" + providerId + "/mechanics",
                HttpMethod.POST, new HttpEntity<>(new CreateMechanicRequest("Someone", null, null),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    /**
     * Provider.vertical is free, unvalidated text (Core never checks it) —
     * a real owner could easily type "Auto" or " auto " when creating their
     * workshop. This proves the vertical check tolerates that, same as
     * vertical-beauty's equivalent test.
     */
    @Test
    void acceptsMechanicCreationRegardlessOfVerticalCasingOrWhitespace() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cased-vertical-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Cased Vertical Workshop " + runId, " Auto ");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auto/providers/" + providerId + "/mechanics",
                HttpMethod.POST, new HttpEntity<>(new CreateMechanicRequest("Someone", null, null),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void fullMechanicDirectoryAndBookingFlow() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "auto-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "auto-customer-" + runId + "@example.com");
        UUID customerId = customer.userId();
        // Case/whitespace-normalized but still an exact vertical match, not
        // a prefix match — see MechanicDirectoryService.isAutoVertical.
        UUID providerId = createProvider(owner, "Speedy Workshop " + runId, "auto");
        UUID serviceId = createService(owner, providerId, "Oil Change", new BigDecimal("35.00"));

        UUID mechanicId = createMechanic(owner, providerId, "Yerlan Mechanic");
        assertThat(mechanicId).isNotNull();

        UUID vehicleId = registerVehicle(customer, "Toyota", "Camry", 2019, "777 ABC 02");
        assertThat(vehicleId).isNotNull();

        // Booking rule: mechanic hasn't been linked to the service yet -> 409.
        UUID slotId = createOpenSlot(owner, providerId);
        ResponseEntity<Map> rejected = restTemplate.exchange("/api/v1/auto/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateAutoBookingRequest(customerId, mechanicId, vehicleId, serviceId, slotId,
                                new BigDecimal("35.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Link mechanic <-> service (owner-only), confirm it shows up.
        restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        List<Map> services = getList("/api/v1/auto/mechanics/" + mechanicId + "/services");
        assertThat(services).extracting(s -> s.get("serviceId")).containsExactly(serviceId.toString());
        // Idempotent: linking again doesn't duplicate.
        restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/auto/mechanics/" + mechanicId + "/services")).hasSize(1);

        // Now the booking succeeds.
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/auto/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateAutoBookingRequest(customerId, mechanicId, vehicleId, serviceId, slotId,
                                new BigDecimal("35.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String bookingId = created.getBody().get("bookingId").toString();
        assertThat(created.getBody().get("mechanicId")).isEqualTo(mechanicId.toString());
        assertThat(created.getBody().get("vehicleId")).isEqualTo(vehicleId.toString());
        // Not CONFIRMED yet — a booking starts PENDING_PAYMENT until its payment succeeds (ADR-0006).
        assertThat(created.getBody().get("status")).isEqualTo("PENDING_PAYMENT");

        // Fetching it back through the auto endpoint (as its own customer) returns the same links.
        Map<?, ?> fetched = restTemplate.exchange("/api/v1/auto/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        assertThat(fetched.get("mechanicId")).isEqualTo(mechanicId.toString());
        assertThat(fetched.get("vehicleId")).isEqualTo(vehicleId.toString());

        // Unlink (owner-only) is idempotent too.
        restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/auto/mechanics/" + mechanicId + "/services")).isEmpty();
        restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
    }

    @Test
    void bookingIsForbiddenWhenTheVehicleBelongsToADifferentUser() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "vehicle-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "vehicle-customer-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate,
                "vehicle-other-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Vehicle Check Workshop " + runId, "auto");
        UUID serviceId = createService(owner, providerId, "Brake Check", new BigDecimal("20.00"));
        UUID mechanicId = createMechanic(owner, providerId, "Test Mechanic");
        restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        UUID slotId = createOpenSlot(owner, providerId);

        // The vehicle belongs to otherCustomer, but the booking is made (with
        // a valid, matching token) as customer -> vehicle ownership rejects it.
        UUID otherCustomersVehicle = registerVehicle(otherCustomer, "Honda", "Civic", 2020, "999 XYZ 01");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auto/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateAutoBookingRequest(customer.userId(), mechanicId, otherCustomersVehicle,
                                serviceId, slotId, new BigDecimal("20.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void vehicleSelfServiceOwnershipIsEnforced() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "veh-self-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "veh-other-" + runId + "@example.com");

        // Can't register a vehicle "owned" by someone else.
        ResponseEntity<Map> forbiddenCreate = restTemplate.exchange("/api/v1/vehicles", HttpMethod.POST,
                new HttpEntity<>(new CreateVehicleRequest(otherCustomer.userId(), "Kia", "Rio", 2021, "111 AAA 01"),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(forbiddenCreate.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        UUID vehicleId = registerVehicle(customer, "Kia", "Rio", 2021, "111 AAA 01");

        // Someone else can't list this customer's vehicles.
        ResponseEntity<Map> forbiddenList = restTemplate.exchange("/api/v1/users/" + customer.userId() + "/vehicles",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(forbiddenList.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        List<Map> owned = getListWithAuth("/api/v1/users/" + customer.userId() + "/vehicles", customer);
        assertThat(owned).extracting(v -> v.get("id")).containsExactly(vehicleId.toString());

        // Someone else can't delete this customer's vehicle.
        ResponseEntity<Map> forbiddenDelete = restTemplate.exchange("/api/v1/vehicles/" + vehicleId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(forbiddenDelete.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deleteResponse = restTemplate.exchange("/api/v1/vehicles/" + vehicleId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Void.class);
        assertThat(deleteResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }

    /**
     * Proves the fix for GET /vehicles/{id}'s missing authorization (Security
     * Audit #4, P1-1): the response includes ownerUserId and licensePlate, so
     * it's owner-only, not just authenticated-only — no token at all gets
     * 401, a different authenticated user gets 403, same
     * getVehicle-then-check-ownership order as VehicleService.deleteVehicle.
     */
    @Test
    void gettingAVehicleRequiresBeingItsOwner() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "veh-get-owner-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "veh-get-other-" + runId
                + "@example.com");
        UUID vehicleId = registerVehicle(customer, "Mazda", "3", 2020, "GET 002");

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/vehicles/" + vehicleId, Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The vehicle's own owner can read it.
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/vehicles/" + vehicleId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(asOwner.getBody().get("id")).isEqualTo(vehicleId.toString());
        assertThat(asOwner.getBody().get("licensePlate")).isEqualTo("GET 002");

        // A different authenticated user cannot.
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/vehicles/" + vehicleId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())), Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void deactivatingAMechanicRemovesItFromTheProviderListingAndReactivationBringsItBack() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "deactivate-auto-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Deactivate Workshop " + runId, "auto");
        UUID mechanicId = createMechanic(owner, providerId, "Temp Mechanic");

        assertThat(getList("/api/v1/auto/providers/" + providerId + "/mechanics")).extracting(m -> m.get("id"))
                .containsExactly(mechanicId.toString());

        // A different owner can't deactivate someone else's mechanic — 403.
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "deactivate-auto-other-owner-" + runId
                + "@example.com");
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())),
                Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deactivateResponse = restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        assertThat(getList("/api/v1/auto/providers/" + providerId + "/mechanics")).isEmpty();

        // Deactivating again (or a non-existent id) is a no-op, not an error.
        ResponseEntity<Void> deactivateAgain = restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // Still invisible by default, but visible with includeInactive=true.
        assertThat(getList("/api/v1/auto/providers/" + providerId + "/mechanics?includeInactive=true"))
                .extracting(m -> m.get("id")).containsExactly(mechanicId.toString());

        ResponseEntity<Map> reactivateResponse = restTemplate.exchange(
                "/api/v1/auto/mechanics/" + mechanicId + "/reactivate", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(reactivateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reactivateResponse.getBody().get("active")).isEqualTo(true);
        assertThat(getList("/api/v1/auto/providers/" + providerId + "/mechanics")).extracting(m -> m.get("id"))
                .containsExactly(mechanicId.toString());
    }

    /**
     * Proves the fix for GET /auto/bookings/{id}'s missing auth/ownership
     * check (Security Audit #4, P0-NEW-1): only the booking's own customer
     * or its provider's own owner may read it — a stranger (customer or
     * unrelated provider owner) gets 403, and no token at all gets 401, same
     * pattern as core BookingController.getById (PR #57).
     */
    @Test
    void gettingAnAutoBookingRequiresBeingItsCustomerOrItsProvidersOwner() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "auto-get-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "auto-get-other-owner-" + runId
                + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "auto-get-customer-" + runId
                + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "auto-get-other-customer-" + runId
                + "@example.com");

        UUID providerId = createProvider(owner, "Get Workshop " + runId, "auto");
        UUID serviceId = createService(owner, providerId, "Get Service", new BigDecimal("30.00"));
        UUID mechanicId = createMechanic(owner, providerId, "Get Mechanic");
        restTemplate.exchange("/api/v1/auto/mechanics/" + mechanicId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        UUID vehicleId = registerVehicle(customer, "Get", "Car", 2022, "GET 001");
        UUID slotId = createOpenSlot(owner, providerId);

        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/auto/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateAutoBookingRequest(customer.userId(), mechanicId, vehicleId, serviceId, slotId,
                                new BigDecimal("30.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(created.getBody().get("bookingId").toString());

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/auto/bookings/" + bookingId,
                Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The booking's own customer can read it.
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/auto/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The provider's own owner can read it too.
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/auto/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.OK);

        // A different customer cannot.
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/auto/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different provider's owner cannot either.
        ResponseEntity<Map> asOtherOwner = restTemplate.exchange("/api/v1/auto/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(asOtherOwner.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    private List<Map> getList(String path) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(path, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private List<Map> getListWithAuth(String path, Registered caller) {
        ResponseEntity<Map[]> response = restTemplate.exchange(path, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(caller.accessToken())), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private UUID createMechanic(Registered owner, UUID providerId, String displayName) {
        var request = new CreateMechanicRequest(displayName, "Bio", null);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auto/providers/" + providerId + "/mechanics",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID registerVehicle(Registered owner, String make, String model, int year, String licensePlate) {
        var request = new CreateVehicleRequest(owner.userId(), make, model, year, licensePlate);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/vehicles", HttpMethod.POST,
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
        var request = new CreateServiceRequest(title, 30, price, "USD");
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
