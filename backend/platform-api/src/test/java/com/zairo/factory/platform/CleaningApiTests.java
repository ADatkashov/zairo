package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.vertical.cleaning.CleanerDtos.CreateCleanerRequest;
import com.zairo.factory.vertical.cleaning.CleaningBookingDtos.CreateCleaningBookingRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
 * Against a real Postgres (Testcontainers): cleaning booking authorization —
 * this vertical had no existing test file at all before Security Audit #4
 * flagged GET /cleaning/bookings/{id} as missing auth/ownership (P0-NEW-1),
 * same bug as the other three vertical booking types.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class CleaningApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    /**
     * Proves the fix for GET /cleaning/bookings/{id}'s missing auth/
     * ownership check (Security Audit #4, P0-NEW-1): only the booking's own
     * customer or its provider's own owner may read it — a stranger
     * (customer or unrelated provider owner) gets 403, and no token at all
     * gets 401, same pattern as core BookingController.getById (PR #57).
     */
    @Test
    void gettingACleaningBookingRequiresBeingItsCustomerOrItsProvidersOwner() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cleaning-get-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "cleaning-get-other-owner-" + runId
                + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "cleaning-get-customer-" + runId
                + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "cleaning-get-other-customer-" + runId
                + "@example.com");

        UUID providerId = createProvider(owner, "Get Cleaning Co " + runId, "cleaning");
        UUID serviceId = createService(owner, providerId, "Get Service", new BigDecimal("60.00"));
        UUID cleanerId = createCleaner(owner, providerId, "Get Cleaner");
        restTemplate.exchange("/api/v1/cleaning/cleaners/" + cleanerId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        UUID slotId = createOpenSlot(owner, providerId);

        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/cleaning/bookings", HttpMethod.POST,
                new HttpEntity<>(
                        new CreateCleaningBookingRequest(customer.userId(), cleanerId, serviceId, slotId,
                                new BigDecimal("60.00")),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(created.getBody().get("bookingId").toString());

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/cleaning/bookings/" + bookingId,
                Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The booking's own customer can read it.
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/cleaning/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The provider's own owner can read it too.
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/cleaning/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.OK);

        // A different customer cannot.
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/cleaning/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different provider's owner cannot either.
        ResponseEntity<Map> asOtherOwner = restTemplate.exchange("/api/v1/cleaning/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(asOtherOwner.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void gettingANonexistentCleaningBookingIs404EvenWhenAuthenticated() {
        Registered customer = TestAuth.registerCustomer(restTemplate, "cleaning-get-missing-" + UUID.randomUUID()
                + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/cleaning/bookings/" + UUID.randomUUID(),
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
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

    private UUID createCleaner(Registered owner, UUID providerId, String displayName) {
        var request = new CreateCleanerRequest(displayName, "Bio", null);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/cleaning/providers/" + providerId
                + "/cleaners", HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
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
