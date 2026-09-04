package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CancelBookingRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
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
@Import({TestcontainersConfiguration.class, TestNotifications.class})
class BookingApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

    @Autowired
    private BookingService bookingService;

    @Test
    void booksAnOpenSlotThenRejectsASecondBookingForTheSameSlot() {
        Registered owner = TestAuth.registerOwner(restTemplate, "owner2@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "customer@example.com");
        UUID customerId = customer.userId();

        UUID providerId = createProvider(owner, "Second Salon");
        UUID serviceId = createService(owner, providerId, "Manicure", new BigDecimal("20.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customerId, serviceId, slotId, new BigDecimal("20.00"));
        ResponseEntity<Map> firstBooking = createBooking(customer, bookingRequest);
        assertThat(firstBooking.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        // Not CONFIRMED yet — a booking starts PENDING_PAYMENT and only
        // confirms once its payment succeeds (see ADR-0006). The slot is
        // already claimed at this point though, which is what this test is
        // actually about — see the rejected second booking below.
        assertThat(firstBooking.getBody().get("status")).isEqualTo("PENDING_PAYMENT");

        ResponseEntity<Map> secondBooking = createBooking(customer, bookingRequest);
        assertThat(secondBooking.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        ResponseEntity<Map[]> userBookings = restTemplate.exchange("/api/v1/users/" + customerId + "/bookings",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map[].class);
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
        ResponseEntity<Map> bookingResponse = createBooking(customer, bookingRequest);
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
        ResponseEntity<Map> bookingResponse = createBooking(customer, bookingRequest);
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

        // Completing requires CONFIRMED first, which requires payment.
        payForBooking(bookingId);

        // A completed booking can no longer be cancelled.
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        ResponseEntity<Map> cancelCompleted = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(cancelCompleted.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void confirmingABookingNotifiesBothTheCustomerAndTheProviderOwner() {
        String runId = UUID.randomUUID().toString();
        String customerEmail = "notify-customer-" + runId + "@example.com";
        String ownerEmail = "notify-owner-" + runId + "@example.com";
        Registered customer = TestAuth.registerCustomer(restTemplate, customerEmail);
        Registered owner = TestAuth.registerOwner(restTemplate, ownerEmail);

        UUID providerId = createProvider(owner, "Notify Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Notify Service", new BigDecimal("25.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("25.00"));
        ResponseEntity<Map> bookingResponse = createBooking(customer, bookingRequest);
        assertThat(bookingResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(bookingResponse.getBody().get("id").toString());

        // Confirmation (and its notifications) now happens on successful
        // payment, not on booking creation — see ADR-0006.
        payForBooking(bookingId);

        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(customerEmail);
            assertThat(email.subject()).isEqualTo("Booking confirmed");
            assertThat(email.body()).contains(bookingId.toString());
        });
        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(ownerEmail);
            assertThat(email.subject()).isEqualTo("New booking received");
            assertThat(email.body()).contains(bookingId.toString());
        });
    }

    @Test
    void sendsABookingReminderOnceAndOnlyOnceForASlotStartingWithinTheWindow() {
        String runId = UUID.randomUUID().toString();
        String customerEmail = "reminder-customer-" + runId + "@example.com";
        Registered customer = TestAuth.registerCustomer(restTemplate, customerEmail);
        Registered owner = TestAuth.registerOwner(restTemplate, "reminder-owner-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Reminder Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Reminder Service", new BigDecimal("25.00"));
        Instant start = Instant.now().plus(30, ChronoUnit.MINUTES);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("25.00"));
        UUID bookingId = UUID.fromString(createBooking(customer, bookingRequest).getBody().get("id").toString());
        payForBooking(bookingId);

        Instant now = Instant.now();
        bookingService.sendDueReminders(now, now.plus(1, ChronoUnit.HOURS));
        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(customerEmail);
            assertThat(email.subject()).isEqualTo("Upcoming booking reminder");
            assertThat(email.body()).contains(bookingId.toString());
        });

        int sentAfterFirstRun = capturedEmails.sent.size();
        bookingService.sendDueReminders(now, now.plus(1, ChronoUnit.HOURS));
        assertThat(capturedEmails.sent).hasSize(sentAfterFirstRun);
    }

    @Test
    void cancellingABookingNotifiesBothTheCustomerAndTheProviderOwner() {
        String runId = UUID.randomUUID().toString();
        String customerEmail = "notify-cancel-customer-" + runId + "@example.com";
        String ownerEmail = "notify-cancel-owner-" + runId + "@example.com";
        Registered customer = TestAuth.registerCustomer(restTemplate, customerEmail);
        Registered owner = TestAuth.registerOwner(restTemplate, ownerEmail);

        UUID providerId = createProvider(owner, "Notify Cancel Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Notify Cancel Service", new BigDecimal("25.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("25.00"));
        ResponseEntity<Map> bookingResponse = createBooking(customer, bookingRequest);
        UUID bookingId = UUID.fromString(bookingResponse.getBody().get("id").toString());

        ResponseEntity<Map> cancelResponse = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(cancelResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(customerEmail);
            assertThat(email.subject()).isEqualTo("Booking cancelled");
            assertThat(email.body()).contains(bookingId.toString());
        });
        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(ownerEmail);
            assertThat(email.subject()).isEqualTo("Booking cancelled");
            assertThat(email.body()).contains("cancelled booking (" + bookingId);
        });
    }

    @Test
    void deletesAnOpenSlotButRefusesToDeleteABookedOne() {
        Registered owner = TestAuth.registerOwner(restTemplate, "owner-slot-delete@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "customer-slot-delete@example.com");

        UUID providerId = createProvider(owner, "Slot Delete Salon");
        UUID serviceId = createService(owner, providerId, "Trim", new BigDecimal("15.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID openSlotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookedSlotId = createSlot(owner, providerId, start.plus(1, ChronoUnit.HOURS),
                start.plus(90, ChronoUnit.MINUTES));
        createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, bookedSlotId, new BigDecimal("15.00")));

        ResponseEntity<Void> deleteOpen = restTemplate.exchange("/api/v1/availability-slots/" + openSlotId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteOpen.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(restTemplate.getForEntity("/api/v1/providers/" + providerId + "/availability-slots", Map[].class)
                .getBody()).extracting(s -> s.get("id")).containsExactly(bookedSlotId.toString());

        ResponseEntity<Map> deleteBooked = restTemplate.exchange("/api/v1/availability-slots/" + bookedSlotId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(deleteBooked.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void cancellingWithAReasonPersistsItAndCancellingWithoutOneLeavesItNull() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "cancel-reason-customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "cancel-reason-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Cancel Reason Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Service", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);

        // With a reason.
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = UUID.fromString(createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("20.00")))
                .getBody().get("id").toString());
        ResponseEntity<Map> withReason = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(new CancelBookingRequest("Change of plans"),
                        TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(withReason.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(withReason.getBody().get("cancellationReason")).isEqualTo("Change of plans");

        // No body at all (existing clients) — still works, reason stays null.
        UUID slotId2 = createSlot(owner, providerId, start.plus(1, ChronoUnit.HOURS), start.plus(90, ChronoUnit.MINUTES));
        UUID bookingId2 = UUID.fromString(createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotId2, new BigDecimal("20.00")))
                .getBody().get("id").toString());
        ResponseEntity<Map> noReason = restTemplate.exchange("/api/v1/bookings/" + bookingId2 + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(noReason.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(noReason.getBody().get("cancellationReason")).isNull();
    }

    @Test
    void providerOwnerMarksANoShowButNotSomeoneElsesProviderOrANonConfirmedBooking() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "noshow-customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "noshow-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "noshow-other-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "No-show Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Service", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = UUID.fromString(createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("20.00")))
                .getBody().get("id").toString());
        payForBooking(bookingId);

        // A different business owner can't mark it.
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/no-show",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // The real owner can.
        ResponseEntity<Map> marked = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/no-show",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(marked.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(marked.getBody().get("status")).isEqualTo("NO_SHOW");

        // Already NO_SHOW (not CONFIRMED anymore) -> rejected.
        ResponseEntity<Map> again = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/no-show",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(again.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
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

    private ResponseEntity<Map> createBooking(Registered customer, CreateBookingRequest request) {
        return restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(customer.accessToken())), Map.class);
    }

    /** Confirms a PENDING_PAYMENT booking — the mock provider always succeeds synchronously. */
    private ResponseEntity<Map> payForBooking(UUID bookingId) {
        return restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments", null, Map.class);
    }
}
