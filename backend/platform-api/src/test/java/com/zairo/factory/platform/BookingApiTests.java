package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

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

    private UUID createUser(String email, String displayName) {
        var request = new CreateUserRequest(email, "+1000000000", displayName, UserRole.CUSTOMER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
