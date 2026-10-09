package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
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

/** A customer's saved cards: saving on a payment, paying with one, removing one. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class, TestNotifications.class})
class SavedCardApiTests {

    private static final String CARDS = "/api/v1/me/payment-cards";

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestPayments.FailureController failureController;

    @AfterEach
    void reset() {
        failureController.noRecurringCharge = false;
    }

    @Test
    void aPaymentDoesNotSaveTheCardUnlessTheCustomerAskedForIt() {
        Registered customer = customer("card-off");
        Booking booking = bookingFor(customer);

        assertThat(pay(booking, customer, null).getStatusCode()).isEqualTo(HttpStatus.CREATED);

        assertThat(cards(customer)).isEmpty();
        assertThat(listBody(customer).get("saveOnNextPayment")).isEqualTo(false);
    }

    @Test
    void thePaymentAfterSwitchingSavingOnKeepsTheCardAndALaterOneCanUseIt() {
        Registered customer = customer("card-on");
        Booking owner = bookingFor(customer);
        setSaveOnNextPayment(customer, true);

        ResponseEntity<Map> first = pay(owner, customer, null);
        assertThat(first.getBody().get("status")).isEqualTo("SUCCEEDED");

        List<Map<String, Object>> saved = cards(customer);
        assertThat(saved).hasSize(1);
        assertThat(saved.get(0).get("last4")).isEqualTo("4242");
        assertThat(saved.get(0).get("brand")).isEqualTo("VISA");
        assertThat(listBody(customer).get("canPayWithSavedCard")).isEqualTo(true);

        // A second booking is paid with that card: charged right away, no payment page.
        Booking second = bookingFor(customer, owner.serviceId, owner.providerId);
        ResponseEntity<Map> withCard = pay(second, customer, UUID.fromString(saved.get(0).get("id").toString()));
        assertThat(withCard.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(withCard.getBody().get("status")).isEqualTo("SUCCEEDED");
        UUID paymentId = UUID.fromString(withCard.getBody().get("id").toString());
        assertThat(failureController.chargeAttempts.get(paymentId).get()).isEqualTo(1);
    }

    @Test
    void anotherCustomersCardCannotBeUsedOrRemoved() {
        Registered alice = customer("card-alice");
        Registered bob = customer("card-bob");
        setSaveOnNextPayment(alice, true);
        pay(bookingFor(alice), alice, null);
        UUID aliceCard = UUID.fromString(cards(alice).get(0).get("id").toString());

        ResponseEntity<Map> attempt = pay(bookingFor(bob), bob, aliceCard);
        assertThat(attempt.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(restTemplate.exchange(CARDS + "/" + aliceCard, HttpMethod.DELETE, auth(bob), Void.class)
                .getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(cards(alice)).hasSize(1);
    }

    @Test
    void aRemovedCardIsGone() {
        Registered customer = customer("card-remove");
        setSaveOnNextPayment(customer, true);
        pay(bookingFor(customer), customer, null);
        UUID card = UUID.fromString(cards(customer).get(0).get("id").toString());

        assertThat(restTemplate.exchange(CARDS + "/" + card, HttpMethod.DELETE, auth(customer), Void.class)
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        assertThat(cards(customer)).isEmpty();
        Booking next = bookingFor(customer);
        assertThat(pay(next, customer, card).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void aProviderThatCannotChargeAStoredCardRefusesToTryAndSaysSo() {
        Registered customer = customer("card-nocharge");
        setSaveOnNextPayment(customer, true);
        pay(bookingFor(customer), customer, null);
        UUID card = UUID.fromString(cards(customer).get(0).get("id").toString());

        failureController.noRecurringCharge = true;
        assertThat(listBody(customer).get("canPayWithSavedCard")).isEqualTo(false);
        assertThat(pay(bookingFor(customer), customer, card).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    // --- helpers -----------------------------------------------------------------------------------------------

    private record Booking(UUID id, UUID serviceId, UUID providerId, Registered owner) {
    }

    private Registered customer(String prefix) {
        return TestAuth.registerCustomer(restTemplate, prefix + "-" + UUID.randomUUID() + "@example.com");
    }

    private Booking bookingFor(Registered customer) {
        return bookingFor(customer, null, null);
    }

    /** A fresh booking awaiting online payment; reuses {@code serviceId}/{@code providerId} when given. */
    private Booking bookingFor(Registered customer, UUID serviceId, UUID providerId) {
        Registered owner = null;
        if (serviceId == null) {
            owner = TestAuth.registerOwner(restTemplate, "card-owner-" + UUID.randomUUID() + "@example.com");
            var providerRequest = new CreateProviderRequest(owner.userId(), "Card Salon " + UUID.randomUUID(), "beauty");
            providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                    new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class)
                    .getBody().get("id").toString());
            TestAuth.requireFullPayment(restTemplate, owner, providerId);
            var serviceRequest = new CreateServiceRequest("Card Service", 30, new BigDecimal("35.00"), "USD");
            serviceId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                    HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                    Map.class).getBody().get("id").toString());
        } else {
            owner = null;
        }
        return newBooking(customer, serviceId, providerId, owner);
    }

    private final Map<UUID, Registered> owners = new java.util.concurrent.ConcurrentHashMap<>();

    private Booking newBooking(Registered customer, UUID serviceId, UUID providerId, Registered ownerOrNull) {
        Registered owner = ownerOrNull != null ? ownerOrNull : owners.get(providerId);
        owners.put(providerId, owner);
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS).plus(owners.size() + (long) (Math.random() * 1000), ChronoUnit.HOURS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/availability-slots",
                HttpMethod.POST, new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class)
                .getBody().get("id").toString());
        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("35.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        return new Booking(UUID.fromString(booking.get("id").toString()), serviceId, providerId, owner);
    }

    private ResponseEntity<Map> pay(Booking booking, Registered customer, UUID savedCardId) {
        Object body = savedCardId == null ? null : Map.of("savedCardId", savedCardId.toString());
        return restTemplate.exchange("/api/v1/bookings/" + booking.id + "/payments", HttpMethod.POST,
                new HttpEntity<>(body, TestAuth.authHeaders(customer.accessToken())), Map.class);
    }

    private HttpEntity<Void> auth(Registered user) {
        return new HttpEntity<>(null, TestAuth.authHeaders(user.accessToken()));
    }

    private Map<?, ?> listBody(Registered customer) {
        return restTemplate.exchange(CARDS, HttpMethod.GET, auth(customer), Map.class).getBody();
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> cards(Registered customer) {
        return (List<Map<String, Object>>) listBody(customer).get("cards");
    }

    private void setSaveOnNextPayment(Registered customer, boolean value) {
        ResponseEntity<Map> response = restTemplate.exchange(CARDS + "/preference", HttpMethod.PUT,
                new HttpEntity<>(Map.of("saveOnNextPayment", value), TestAuth.authHeaders(customer.accessToken())),
                Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
