package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserRole;
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
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * End-to-end: owner -> provider -> service -> availability slot -> booking,
 * against a real Postgres (Testcontainers). Also proves the slot-conflict
 * check (@Version optimistic locking in BookingService) actually rejects a
 * second booking attempt on an already-booked slot.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class BookingApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void booksAnOpenSlotThenRejectsASecondBookingForTheSameSlot() {
        UUID ownerId = createUser("owner2@example.com", "Salon Owner 2");
        UUID customerId = createUser("customer@example.com", "Customer");

        var providerRequest = new CreateProviderRequest(ownerId, "Second Salon", "beauty");
        Map<?, ?> provider = restTemplate.postForEntity("/api/v1/providers", providerRequest, Map.class).getBody();
        UUID providerId = UUID.fromString(provider.get("id").toString());

        var serviceRequest = new CreateServiceRequest("Manicure", 30, new BigDecimal("20.00"), "USD");
        Map<?, ?> service = restTemplate
                .postForEntity("/api/v1/providers/" + providerId + "/services", serviceRequest, Map.class).getBody();
        UUID serviceId = UUID.fromString(service.get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.postForEntity(
                "/api/v1/providers/" + providerId + "/availability-slots", slotRequest, Map.class);
        assertThat(slotResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());

        var bookingRequest = new CreateBookingRequest(customerId, serviceId, slotId, new BigDecimal("20.00"));
        ResponseEntity<Map> firstBooking = restTemplate.postForEntity("/api/v1/bookings", bookingRequest, Map.class);
        assertThat(firstBooking.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(firstBooking.getBody().get("status")).isEqualTo("CONFIRMED");

        ResponseEntity<Map> secondBooking = restTemplate.postForEntity("/api/v1/bookings", bookingRequest,
                Map.class);
        assertThat(secondBooking.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        ResponseEntity<Map[]> userBookings = restTemplate.getForEntity("/api/v1/users/" + customerId + "/bookings",
                Map[].class);
        assertThat(userBookings.getBody()).hasSize(1);
    }

    @Test
    void deletesAnOpenSlotButRefusesToDeleteABookedOne() {
        Registered owner = registerOwner("owner-slot-delete@example.com");
        UUID ownerId = owner.userId();
        UUID customerId = createUser("customer-slot-delete@example.com", "Slot Delete Customer");

        var providerRequest = new CreateProviderRequest(ownerId, "Slot Delete Salon", "beauty");
        Map<?, ?> provider = restTemplate.postForEntity("/api/v1/providers", providerRequest, Map.class).getBody();
        UUID providerId = UUID.fromString(provider.get("id").toString());

        var serviceRequest = new CreateServiceRequest("Trim", 30, new BigDecimal("15.00"), "USD");
        Map<?, ?> service = restTemplate
                .postForEntity("/api/v1/providers/" + providerId + "/services", serviceRequest, Map.class).getBody();
        UUID serviceId = UUID.fromString(service.get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var openSlotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID openSlotId = UUID.fromString(restTemplate
                .postForEntity("/api/v1/providers/" + providerId + "/availability-slots", openSlotRequest, Map.class)
                .getBody().get("id").toString());

        var bookedSlotRequest = new CreateAvailabilitySlotRequest(start.plus(1, ChronoUnit.HOURS),
                start.plus(90, ChronoUnit.MINUTES));
        UUID bookedSlotId = UUID.fromString(restTemplate
                .postForEntity("/api/v1/providers/" + providerId + "/availability-slots", bookedSlotRequest,
                        Map.class)
                .getBody().get("id").toString());
        restTemplate.postForEntity("/api/v1/bookings",
                new CreateBookingRequest(customerId, serviceId, bookedSlotId, new BigDecimal("15.00")), Map.class);

        ResponseEntity<Void> deleteOpen = restTemplate.exchange("/api/v1/availability-slots/" + openSlotId,
                HttpMethod.DELETE, new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteOpen.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(restTemplate.getForEntity("/api/v1/providers/" + providerId + "/availability-slots", Map[].class)
                .getBody()).extracting(s -> s.get("id")).containsExactly(bookedSlotId.toString());

        ResponseEntity<Map> deleteBooked = restTemplate.exchange("/api/v1/availability-slots/" + bookedSlotId,
                HttpMethod.DELETE, new HttpEntity<>(null, authHeaders(owner.accessToken())), Map.class);
        assertThat(deleteBooked.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
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

    private UUID createUser(String email, String displayName) {
        var request = new CreateUserRequest(email, "+1000000000", displayName, UserRole.CUSTOMER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
