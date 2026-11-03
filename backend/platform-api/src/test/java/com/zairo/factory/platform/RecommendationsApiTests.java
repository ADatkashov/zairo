package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserRepository;
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
 * Against a real Postgres (Testcontainers) -- recommendations learned from a customer's real bookings. The database is
 * shared with other test classes, so the businesses here use random per-run categories.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class RecommendationsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Test
    void recommendsUntriedBusinessesOfTheCategoriesTheCustomerBooksInAndOnlyToThem() {
        String run = UUID.randomUUID().toString().substring(0, 8);
        String booked = "rec-booked-" + run;
        Registered ownerA = TestAuth.registerOwner(restTemplate, "rec-a-" + run + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "rec-b-" + run + "@example.com");
        Registered ownerC = TestAuth.registerOwner(restTemplate, "rec-c-" + run + "@example.com");
        Registered ownerD = TestAuth.registerOwner(restTemplate, "rec-d-" + run + "@example.com");
        Registered ownerE = TestAuth.registerOwner(restTemplate, "rec-e-" + run + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "rec-cust-" + run + "@example.com");
        Registered newcomer = TestAuth.registerCustomer(restTemplate, "rec-new-" + run + "@example.com");

        UUID visited = createProvider(ownerA, "Rec Visited " + run, booked);
        UUID untriedB = createProvider(ownerB, "Rec Untried B " + run, booked);
        UUID untriedC = createProvider(ownerC, "Rec Untried C " + run, booked);
        UUID otherCategory = createProvider(ownerD, "Rec Other " + run, "rec-other-" + run);
        UUID pending = createProvider(ownerE, "Rec Pending " + run, booked);
        for (UUID id : List.of(visited, untriedB, untriedC, otherCategory)) {
            approve(id);
        }
        // `pending` stays PENDING: not discoverable, so not recommendable.

        UUID service = createService(ownerA, visited);
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slot = createSlot(ownerA, visited, start, start.plus(30, ChronoUnit.MINUTES));
        var booking = new CreateBookingRequest(customer.userId(), service, slot, new BigDecimal("25.00"));
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(booking, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        List<Map<String, Object>> recommended = get(customer, customer.userId(), "").getBody();
        assertThat(recommended).extracting(r -> r.get("providerId"))
                .containsExactlyInAnyOrder(untriedB.toString(), untriedC.toString());
        assertThat(recommended).extracting(r -> r.get("vertical")).containsOnly(booked);
        assertThat(recommended).extracting(r -> r.get("providerId"))
                .doesNotContain(visited.toString(), otherCategory.toString(), pending.toString());

        assertThat(get(customer, customer.userId(), "?limit=1").getBody()).hasSize(1);
        // A city none of them is in: they have set no city, so they still count (nothing disappears while owners fill
        // their profile in).
        assertThat(get(customer, customer.userId(), "?city=no-such-city-" + run).getBody()).hasSize(2);

        // Self-service only; and a customer with no history has nothing to learn from.
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/users/" + customer.userId() + "/recommendations",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(newcomer.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(get(newcomer, newcomer.userId(), "").getBody()).isEmpty();
    }

    @SuppressWarnings("unchecked")
    private ResponseEntity<List<Map<String, Object>>> get(Registered caller, UUID userId, String query) {
        return (ResponseEntity<List<Map<String, Object>>>) (ResponseEntity<?>) restTemplate.exchange(
                "/api/v1/users/" + userId + "/recommendations" + query, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(caller.accessToken())), List.class);
    }

    private void approve(UUID providerId) {
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "rec-admin-" + UUID.randomUUID() + "@example.com");
        var request = new UpdateProviderStatusRequest(ProviderStatus.ACTIVE);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/status",
                HttpMethod.PATCH, new HttpEntity<>(request, TestAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private UUID createProvider(Registered owner, String name, String vertical) {
        var request = new CreateProviderRequest(owner.userId(), name, vertical);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createService(Registered owner, UUID providerId) {
        var request = new CreateServiceRequest("Rec Service", 30, new BigDecimal("25.00"), "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createSlot(Registered owner, UUID providerId, Instant startsAt, Instant endsAt) {
        var request = new CreateAvailabilitySlotRequest(startsAt, endsAt);
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
