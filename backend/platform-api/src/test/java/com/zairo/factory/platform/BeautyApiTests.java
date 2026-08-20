package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

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
        UUID ownerId = createUser("beauty-owner-" + runId + "@example.com");
        UUID customerId = createUser("beauty-customer-" + runId + "@example.com");
        // Vertical must be the exact literal "beauty" -- MasterDirectoryService checks it
        // precisely (see createMaster's javadoc), not a prefix match.
        UUID providerId = createProvider(ownerId, "Glow Salon " + runId, "beauty");
        UUID serviceId = createService(providerId, "Balayage", new BigDecimal("120.00"));

        UUID masterId = createMaster(providerId, "Jamie Stylist");
        assertThat(masterId).isNotNull();

        // Portfolio.
        restTemplate.postForEntity("/api/v1/beauty/masters/" + masterId + "/portfolio",
                new AddPortfolioItemRequest("https://example.com/photo1.jpg", "Balayage look"), Map.class);
        List<Map> portfolio = getList("/api/v1/beauty/masters/" + masterId + "/portfolio");
        assertThat(portfolio).hasSize(1);
        assertThat(portfolio.get(0).get("caption")).isEqualTo("Balayage look");

        // Booking rule: master hasn't been linked to the service yet -> 409.
        UUID slotId = createOpenSlot(providerId);
        ResponseEntity<Map> rejected = restTemplate.postForEntity("/api/v1/beauty/bookings",
                new CreateBeautyBookingRequest(customerId, masterId, serviceId, slotId, new BigDecimal("120.00")),
                Map.class);
        assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Link master <-> service, confirm it shows up.
        restTemplate.postForEntity("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, null,
                Void.class);
        List<Map> services = getList("/api/v1/beauty/masters/" + masterId + "/services");
        assertThat(services).extracting(s -> s.get("serviceId")).containsExactly(serviceId.toString());
        // Idempotent: linking again doesn't duplicate.
        restTemplate.postForEntity("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId, null,
                Void.class);
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

        // Unlink is idempotent too.
        restTemplate.delete("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId);
        assertThat(getList("/api/v1/beauty/masters/" + masterId + "/services")).isEmpty();
        restTemplate.delete("/api/v1/beauty/masters/" + masterId + "/services/" + serviceId);
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
