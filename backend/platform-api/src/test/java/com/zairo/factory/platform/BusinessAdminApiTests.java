package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserRole;
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

/** Against a real Postgres (Testcontainers): the two read endpoints the Business Admin app needs — "my salons" and "my salon's bookings". */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class BusinessAdminApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void listsProvidersOwnedByAUser() {
        String runId = UUID.randomUUID().toString();
        UUID ownerId = createUser("admin-owner-" + runId + "@example.com", UserRole.PROVIDER_OWNER);
        UUID otherOwnerId = createUser("admin-other-" + runId + "@example.com", UserRole.PROVIDER_OWNER);

        UUID providerA = createProvider(ownerId, "Owner Salon A " + runId);
        UUID providerB = createProvider(ownerId, "Owner Salon B " + runId);
        createProvider(otherOwnerId, "Someone Else's Salon " + runId);

        List<Map> owned = getList("/api/v1/users/" + ownerId + "/providers");
        assertThat(owned).extracting(p -> p.get("id")).containsExactlyInAnyOrder(providerA.toString(),
                providerB.toString());
    }

    @Test
    void listsBookingsForAProvider() {
        String runId = UUID.randomUUID().toString();
        UUID ownerId = createUser("admin-booking-owner-" + runId + "@example.com", UserRole.PROVIDER_OWNER);
        UUID customerId = createUser("admin-booking-customer-" + runId + "@example.com", UserRole.CUSTOMER);
        UUID providerId = createProvider(ownerId, "Booking Admin Salon " + runId);
        UUID serviceId = createService(providerId, "Cut", new BigDecimal("20.00"));

        // No bookings yet.
        assertThat(getList("/api/v1/providers/" + providerId + "/bookings")).isEmpty();

        UUID slotId = createOpenSlot(providerId);
        ResponseEntity<Map> booking = restTemplate.postForEntity("/api/v1/bookings", Map.of(
                "userId", customerId,
                "serviceId", serviceId,
                "availabilitySlotId", slotId,
                "totalPrice", new BigDecimal("20.00")), Map.class);
        assertThat(booking.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String bookingId = booking.getBody().get("id").toString();

        List<Map> bookings = getList("/api/v1/providers/" + providerId + "/bookings");
        assertThat(bookings).extracting(b -> b.get("id")).containsExactly(bookingId);
    }

    private List<Map> getList(String path) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(path, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private UUID createProvider(UUID ownerId, String name) {
        var request = new CreateProviderRequest(ownerId, name, "beauty");
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/providers", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }

    private UUID createService(UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/providers/" + providerId + "/services", request,
                Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }

    private UUID createOpenSlot(UUID providerId) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var request = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/providers/" + providerId + "/availability-slots",
                request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }

    private UUID createUser(String email, UserRole role) {
        var request = new CreateUserRequest(email, "+1000000000", "Admin Test User", role);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
