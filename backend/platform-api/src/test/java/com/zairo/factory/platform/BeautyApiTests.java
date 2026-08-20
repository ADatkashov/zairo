package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserRole;
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
import org.springframework.http.HttpHeaders;
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
        UUID ownerId = createUser("non-beauty-owner-" + runId + "@example.com");
        UUID providerId = createProvider(ownerId, "Quick Lube " + runId, "auto-" + runId);

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/beauty/providers/" + providerId
                + "/masters", new CreateMasterRequest("Someone", null, null), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void fullMasterDirectoryAndBookingFlow() {
        String runId = UUID.randomUUID().toString();
        Registered owner = registerOwner("beauty-owner-" + runId + "@example.com");
        UUID customerId = createUser("beauty-customer-" + runId + "@example.com");
        // Vertical must be the exact literal "beauty" -- MasterDirectoryService checks it
        // precisely (see createMaster's javadoc), not a prefix match.
        UUID providerId = createProvider(owner.userId(), "Glow Salon " + runId, "beauty");
        UUID serviceId = createService(providerId, "Balayage", new BigDecimal("120.00"));

        UUID masterId = createMaster(providerId, "Jamie Stylist");
        assertThat(masterId).isNotNull();

        // Portfolio — owner-only.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/portfolio", HttpMethod.POST,
                new HttpEntity<>(new AddPortfolioItemRequest("https://example.com/photo1.jpg", "Balayage look"),
                        authHeaders(owner.accessToken())),
                Map.class);
        List<Map> portfolio = getList("/api/v1/beauty/masters/" + masterId + "/portfolio");
        assertThat(portfolio).hasSize(1);
        assertThat(portfolio.get(0).get("caption")).isEqualTo("Balayage look");

        // Booking rule: master hasn't been linked to the service yet -> 409.
        UUID slotId = createOpenSlot(providerId);
        ResponseEntity<Map> rejected = restTemplate.postForEntity("/api/v1/beauty/bookings",
                new CreateBeautyBookingRequest(customerId, masterId, serviceId, slotId, new BigDecimal("120.00")),
                Map.class);
        assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Link master <-> service (owner-only), confirm it shows up.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        List<Map> services = getList("/api/v1/beauty/masters/" + masterId + "/services");
        assertThat(services).extracting(s -> s.get("serviceId")).containsExactly(serviceId.toString());
        // Idempotent: linking again doesn't duplicate.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.POST,
                new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/beauty/masters/" + masterId + "/services")).hasSize(1);

        // Now the booking succeeds.
        ResponseEntity<Map> created = restTemplate.postForEntity("/api/v1/beauty/bookings",
                new CreateBeautyBookingRequest(customerId, masterId, serviceId, slotId, new BigDecimal("120.00")),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String bookingId = created.getBody().get("bookingId").toString();
        assertThat(created.getBody().get("masterId")).isEqualTo(masterId.toString());
        assertThat(created.getBody().get("status")).isEqualTo("CONFIRMED");

        // Fetching it back through the beauty endpoint returns the same master link.
        Map<?, ?> fetched = restTemplate.getForEntity("/api/v1/beauty/bookings/" + bookingId, Map.class).getBody();
        assertThat(fetched.get("masterId")).isEqualTo(masterId.toString());

        // Unlink (owner-only) is idempotent too.
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        assertThat(getList("/api/v1/beauty/masters/" + masterId + "/services")).isEmpty();
        restTemplate.exchange("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
    }

    @Test
    void deactivatingAMasterRemovesItFromTheProviderListing() {
        String runId = UUID.randomUUID().toString();
        Registered owner = registerOwner("deactivate-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner.userId(), "Deactivate Salon " + runId, "beauty");
        UUID masterId = createMaster(providerId, "Temp Master");

        assertThat(getList("/api/v1/beauty/providers/" + providerId + "/masters")).extracting(m -> m.get("id"))
                .containsExactly(masterId.toString());

        // A different owner can't deactivate someone else's master — 403.
        Registered otherOwner = registerOwner("deactivate-other-owner-" + runId + "@example.com");
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/beauty/masters/" + masterId,
                HttpMethod.DELETE, new HttpEntity<>(null, authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deactivateResponse = restTemplate.exchange("/api/v1/beauty/masters/" + masterId,
                HttpMethod.DELETE, new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        assertThat(getList("/api/v1/beauty/providers/" + providerId + "/masters")).isEmpty();

        // Deactivating again (or a non-existent id) is a no-op, not an error.
        ResponseEntity<Void> deactivateAgain = restTemplate.exchange("/api/v1/beauty/masters/" + masterId,
                HttpMethod.DELETE, new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        assertThat(deactivateAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }

    private record Registered(UUID userId, String accessToken) {
    }

    private Registered registerOwner(String email) {
        var request = new RegisterRequest(email, "password123", "Registered Owner", "+1000000002",
                UserRole.PROVIDER_OWNER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/auth/register", request, Map.class).getBody();
        UUID userId = UUID.fromString(((Map<?, ?>) body.get("user")).get("id").toString());
        return new Registered(userId, body.get("accessToken").toString());
    }

    private HttpHeaders authHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return headers;
    }

    private List<Map> getList(String path) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(path, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private UUID createMaster(UUID providerId, String displayName) {
        var request = new CreateMasterRequest(displayName, "Bio", null);
        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/beauty/providers/" + providerId
                + "/masters", request, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createProvider(UUID ownerId, String name, String vertical) {
        var request = new CreateProviderRequest(ownerId, name, vertical);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/providers", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }

    private UUID createService(UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 60, price, "USD");
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/providers/" + providerId + "/services", request,
                Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }

    private UUID createOpenSlot(UUID providerId) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var request = new CreateAvailabilitySlotRequest(start, start.plus(60, ChronoUnit.MINUTES));
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/providers/" + providerId + "/availability-slots",
                request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }

    private UUID createUser(String email) {
        var request = new CreateUserRequest(email, "+1000000000", "Beauty Test User", UserRole.PROVIDER_OWNER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
