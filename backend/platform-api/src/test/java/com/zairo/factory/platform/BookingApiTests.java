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
    void aBookingSaysWhatWasBookedWithWhomAndWhenEverywhereItIsReturned() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "details-owner-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "details-customer-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Details Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Gel manicure", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
        Instant end = start.plus(30, ChronoUnit.MINUTES);
        UUID slotId = createSlot(owner, providerId, start, end);

        ResponseEntity<Map> created = createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("20.00")));
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID bookingId = UUID.fromString(created.getBody().get("id").toString());

        ResponseEntity<Map[]> mine = restTemplate.exchange("/api/v1/users/" + customer.userId() + "/bookings",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map[].class);
        ResponseEntity<Map> byId = restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        ResponseEntity<Map[]> received = restTemplate.exchange("/api/v1/providers/" + providerId + "/bookings",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map[].class);

        assertThat(mine.getBody()).hasSize(1);
        assertThat(received.getBody()).hasSize(1);
        for (Map<?, ?> booking : new Map<?, ?>[] {created.getBody(), mine.getBody()[0], byId.getBody(),
                received.getBody()[0]}) {
            assertThat(booking.get("serviceTitle")).isEqualTo("Gel manicure");
            assertThat(booking.get("providerId")).isEqualTo(providerId.toString());
            assertThat(booking.get("providerName")).isEqualTo("Details Salon " + runId);
            assertThat(booking.get("providerVertical")).isEqualTo("beauty");
            assertThat(Instant.parse(booking.get("startsAt").toString())).isEqualTo(start);
            assertThat(Instant.parse(booking.get("endsAt").toString())).isEqualTo(end);
        }
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
        payForBooking(bookingId, customer);

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
        payForBooking(bookingId, customer);

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
        payForBooking(bookingId, customer);

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
        payForBooking(bookingId, customer);

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

    /**
     * Proves the fix for GET /bookings/{id}'s missing auth/ownership check:
     * only the booking's own customer or its provider's own owner may read
     * it — a stranger (customer or unrelated provider owner) gets 403, and
     * no token at all gets 401, matching the same pattern already used by
     * cancel/complete/no-show.
     */
    @Test
    void gettingABookingRequiresBeingItsCustomerOrItsProvidersOwner() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "get-customer-" + runId + "@example.com");
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate, "get-other-customer-" + runId
                + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "get-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "get-other-owner-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Get Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Get Service", new BigDecimal("20.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = UUID.fromString(createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("20.00")))
                .getBody().get("id").toString());

        // No token at all -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/bookings/" + bookingId, Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The booking's own customer can read it.
        ResponseEntity<Map> asCustomer = restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(asCustomer.getBody().get("id")).isEqualTo(bookingId.toString());

        // The provider's own owner can read it too.
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.OK);

        // A different customer cannot.
        ResponseEntity<Map> asOtherCustomer = restTemplate.exchange("/api/v1/bookings/" + bookingId,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken())),
                Map.class);
        assertThat(asOtherCustomer.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A different provider's owner cannot either.
        ResponseEntity<Map> asOtherOwner = restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(asOtherOwner.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void gettingANonexistentBookingIs404EvenWhenAuthenticated() {
        Registered customer = TestAuth.registerCustomer(restTemplate, "get-missing-" + UUID.randomUUID()
                + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + UUID.randomUUID(),
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    /**
     * Proves the fix for the price-tampering hole: whatever totalPrice the
     * client sends — correct, lowballed, or wildly inflated — the booking
     * (and the payment actually charged against it) always ends up priced
     * at the service's own current price, never the client's number.
     */
    @Test
    void bookingPriceAlwaysComesFromTheServiceNeverFromTheClientRequest() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "price-customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "price-owner-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Price Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Price Service", new BigDecimal("500.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);

        // Client sends the correct price — still served from the service,
        // not merely echoed back.
        UUID slotCorrect = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> correct = createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotCorrect, new BigDecimal("500.00")));
        assertThat(correct.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(correct.getBody().get("totalPrice")).isEqualTo(500.00);

        // Client lowballs the price (0.01 vs the real 500.00) — the booking
        // is still created at the service's real price, not the client's.
        UUID slotLow = createSlot(owner, providerId, start.plus(1, ChronoUnit.HOURS),
                start.plus(90, ChronoUnit.MINUTES));
        ResponseEntity<Map> lowball = createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotLow, new BigDecimal("0.01")));
        assertThat(lowball.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(lowball.getBody().get("totalPrice")).isEqualTo(500.00);
        UUID lowballBookingId = UUID.fromString(lowball.getBody().get("id").toString());

        // Client inflates the price (999999 vs the real 500.00) — same
        // result, the service's price wins either direction.
        UUID slotHigh = createSlot(owner, providerId, start.plus(2, ChronoUnit.HOURS),
                start.plus(150, ChronoUnit.MINUTES));
        ResponseEntity<Map> inflated = createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceId, slotHigh, new BigDecimal("999999")));
        assertThat(inflated.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(inflated.getBody().get("totalPrice")).isEqualTo(500.00);

        // The actual charge (Payments) is computed from the booking's
        // server-side price too — the 0.01 the client tried to sneak in on
        // the lowballed booking never reaches the payment provider.
        ResponseEntity<Map> payment = restTemplate.exchange("/api/v1/bookings/" + lowballBookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(payment.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(payment.getBody().get("amount")).isEqualTo(500.00);
    }

    /**
     * Proves the fix for the service/slot provider-consistency hole: a
     * service from one provider can't be booked against a time slot that
     * belongs to a completely different provider.
     */
    @Test
    void aServiceFromOneProviderCannotBeBookedAgainstAnotherProvidersSlot() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "mismatch-customer-" + runId
                + "@example.com");
        Registered ownerA = TestAuth.registerOwner(restTemplate, "mismatch-ownerA-" + runId + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "mismatch-ownerB-" + runId + "@example.com");

        UUID providerA = createProvider(ownerA, "Mismatch Salon A " + runId);
        UUID serviceA = createService(ownerA, providerA, "Service A", new BigDecimal("500.00"));

        UUID providerB = createProvider(ownerB, "Mismatch Salon B " + runId);
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotB = createSlot(ownerB, providerB, start, start.plus(30, ChronoUnit.MINUTES));

        ResponseEntity<Map> response = createBooking(customer,
                new CreateBookingRequest(customer.userId(), serviceA, slotB, new BigDecimal("500.00")));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // The rejected attempt never claimed provider B's slot.
        ResponseEntity<Map[]> slots = restTemplate.getForEntity(
                "/api/v1/providers/" + providerB + "/availability-slots", Map[].class);
        assertThat(slots.getBody()).extracting(s -> s.get("status")).containsExactly("OPEN");
    }

    @Test
    void providerScheduleListsBookingsWithSlotTimesForTheOwnerOnly() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "schedule-owner-" + runId + "@example.com");
        Registered other = TestAuth.registerOwner(restTemplate, "schedule-other-" + runId + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "schedule-customer-" + runId + "@example.com");

        UUID providerId = createProvider(owner, "Schedule Salon");
        UUID serviceId = createService(owner, providerId, "Haircut", new BigDecimal("15.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        createSlot(owner, providerId, start.plus(2, ChronoUnit.HOURS), start.plus(150, ChronoUnit.MINUTES));
        assertThat(createBooking(customer, new CreateBookingRequest(customer.userId(), serviceId, slotId,
                new BigDecimal("15.00"))).getStatusCode()).isEqualTo(HttpStatus.CREATED);

        String url = "/api/v1/providers/" + providerId + "/schedule?from=" + start.minus(1, ChronoUnit.HOURS)
                + "&to=" + start.plus(1, ChronoUnit.DAYS);
        ResponseEntity<Map[]> schedule = restTemplate.exchange(url, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map[].class);
        assertThat(schedule.getStatusCode()).isEqualTo(HttpStatus.OK);
        // Only the booked slot appears; the open one has no booking.
        assertThat(schedule.getBody()).hasSize(1);
        assertThat(schedule.getBody()[0].get("availabilitySlotId")).isEqualTo(slotId.toString());
        assertThat(Instant.parse(schedule.getBody()[0].get("startsAt").toString())).isEqualTo(start);

        assertThat(restTemplate.exchange(url, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(other.accessToken())), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);

        String tooWide = "/api/v1/providers/" + providerId + "/schedule?from=" + start + "&to="
                + start.plus(40, ChronoUnit.DAYS);
        assertThat(restTemplate.exchange(tooWide, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString(response.getBody().get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        return providerId;
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
    private ResponseEntity<Map> payForBooking(UUID bookingId, Registered customer) {
        return restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
    }
}
