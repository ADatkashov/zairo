package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
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
        Registered owner = TestAuth.registerOwner(restTemplate, "owner2@example.com");
        UUID customerId = createUser("customer@example.com", "Customer");

        UUID providerId = createProvider(owner, "Second Salon");
        UUID serviceId = createService(owner, providerId, "Manicure", new BigDecimal("20.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

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
    void customerCancelsTheirOwnConfirmedBookingAndTheSlotReopens() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "cancel-customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "cancel-owner-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Cancel Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Cancel Service", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("20.00"));
        ResponseEntity<Map> bookingResponse = restTemplate.postForEntity("/api/v1/bookings", bookingRequest,
                Map.class);
        UUID bookingId = UUID.fromString(bookingResponse.getBody().get("id").toString());

        ResponseEntity<Map> cancelResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(cancelResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(cancelResponse.getBody().get("status")).isEqualTo("CANCELLED");

        // Slot released back to OPEN — someone else can book it again.
        ResponseEntity<Map[]> slots = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/availability-slots", Map[].class);
        assertThat(slots.getBody()).extracting(s -> s.get("status")).containsExactly("OPEN");

        // Cancelling an already-cancelled booking is rejected.
        ResponseEntity<Map> secondCancel = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(secondCancel.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void cancellingSomeoneElsesBookingIsForbiddenAndCancellingACompletedBookingIsRejected() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "cancel-owner2-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "cancel-other-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "cancel-owner3-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Cancel Forbidden Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Cancel Service 2", new BigDecimal("15.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("15.00"));
        ResponseEntity<Map> bookingResponse = restTemplate.postForEntity("/api/v1/bookings", bookingRequest,
                Map.class);
        UUID bookingId = UUID.fromString(bookingResponse.getBody().get("id").toString());

        // A different customer can't cancel this booking.
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/cancel",
                null, Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // A completed booking can no longer be cancelled.
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/complete", null, Map.class);
        ResponseEntity<Map> cancelCompleted = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(cancelCompleted.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void deletesAnOpenSlotButRefusesToDeleteABookedOne() {
        Registered owner = TestAuth.registerOwner(restTemplate, "owner-slot-delete@example.com");
        UUID customerId = createUser("customer-slot-delete@example.com", "Slot Delete Customer");

        UUID providerId = createProvider(owner, "Slot Delete Salon");
        UUID serviceId = createService(owner, providerId, "Trim", new BigDecimal("15.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID openSlotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookedSlotId = createSlot(owner, providerId, start.plus(1, ChronoUnit.HOURS),
                start.plus(90, ChronoUnit.MINUTES));
        restTemplate.postForEntity("/api/v1/bookings",
                new CreateBookingRequest(customerId, serviceId, bookedSlotId, new BigDecimal("15.00")), Map.class);

        ResponseEntity<Void> deleteOpen = restTemplate.exchange("/api/v1/availability-slots/" + openSlotId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteOpen.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(restTemplate.getForEntity("/api/v1/providers/" + providerId + "/availability-slots", Map[].class)
                .getBody()).extracting(s -> s.get("id")).containsExactly(bookedSlotId.toString());

        ResponseEntity<Map> deleteBooked = restTemplate.exchange("/api/v1/availability-slots/" + bookedSlotId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(deleteBooked.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
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

    private UUID createSlot(Registered owner, UUID providerId, Instant startsAt, Instant endsAt) {
        var request = new CreateAvailabilitySlotRequest(startsAt, endsAt);
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createUser(String email, String displayName) {
        var request = new CreateUserRequest(email, "+1000000000", displayName, UserRole.CUSTOMER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
