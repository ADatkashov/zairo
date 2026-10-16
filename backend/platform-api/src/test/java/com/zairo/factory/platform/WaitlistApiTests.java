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
 * Against a real Postgres (Testcontainers): a customer waits for a fully booked business, another customer cancels,
 * and the waiting one is told — once, and only when the freed time is one they asked for.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class})
class WaitlistApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

    @Test
    void tellsAWaitingCustomerOnceWhenSomeoneElseCancelsAMatchingTime() {
        String runId = UUID.randomUUID().toString();
        String waitingEmail = "waiting-" + runId + "@example.com";
        Registered waiting = TestAuth.registerCustomer(restTemplate, waitingEmail);
        Registered booker = TestAuth.registerCustomer(restTemplate, "booker-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "waitlist-owner-" + runId + "@example.com");
        String providerName = "Waitlist Salon " + runId;
        UUID providerId = createProvider(owner, providerName);
        UUID serviceId = createService(owner, providerId);

        Instant start = Instant.now().plus(2, ChronoUnit.DAYS);
        UUID bookingId = bookNewSlot(owner, booker, providerId, serviceId, start);

        // Wants that very day: from an hour before to an hour after the visit.
        assertThat(join(waiting, providerId, Map.of("from", start.minus(1, ChronoUnit.HOURS).toString(), "to",
                start.plus(1, ChronoUnit.HOURS).toString())).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        ResponseEntity<List> listed = restTemplate.exchange("/api/v1/users/" + waiting.userId() + "/waitlist",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(waiting.accessToken())), List.class);
        assertThat(listed.getBody()).hasSize(1);
        assertThat(((Map<?, ?>) listed.getBody().get(0)).get("providerName")).isEqualTo(providerName);

        cancel(booker, bookingId);

        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(waitingEmail);
            assertThat(email.subject()).isEqualTo("A time just opened up");
            assertThat(email.body()).contains(providerName);
        });
        // The customer who gave the time up is not told it "opened"...
        assertThat(toldATimeOpened("booker-" + runId + "@example.com")).isFalse();
        // ...and the waiting customer is off the list: told once.
        ResponseEntity<List> after = restTemplate.exchange("/api/v1/users/" + waiting.userId() + "/waitlist",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(waiting.accessToken())), List.class);
        assertThat(after.getBody()).isEmpty();
    }

    @Test
    void doesNotTellACustomerAboutATimeOutsideTheirWindow() {
        String runId = UUID.randomUUID().toString();
        String waitingEmail = "window-waiting-" + runId + "@example.com";
        Registered waiting = TestAuth.registerCustomer(restTemplate, waitingEmail);
        Registered booker = TestAuth.registerCustomer(restTemplate, "window-booker-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "window-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Window Salon " + runId);
        UUID serviceId = createService(owner, providerId);

        Instant start = Instant.now().plus(5, ChronoUnit.DAYS);
        UUID bookingId = bookNewSlot(owner, booker, providerId, serviceId, start);

        // Only wants tomorrow; the freed time is in five days.
        Instant tomorrow = Instant.now().plus(1, ChronoUnit.DAYS);
        join(waiting, providerId, Map.of("from", tomorrow.toString(), "to",
                tomorrow.plus(1, ChronoUnit.DAYS).toString()));

        cancel(booker, bookingId);

        assertThat(toldATimeOpened(waitingEmail)).isFalse();
        ResponseEntity<List> still = restTemplate.exchange("/api/v1/users/" + waiting.userId() + "/waitlist",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(waiting.accessToken())), List.class);
        assertThat(still.getBody()).hasSize(1);
    }

    @Test
    void joiningWithoutAWindowMeansAnyTimeAndLeavingIsIdempotent() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "any-time-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "any-time-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Any Time Salon " + runId);

        assertThat(join(customer, providerId, null).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        // Joining twice is fine and keeps one entry.
        assertThat(join(customer, providerId, null).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        var auth = new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken()));
        String listUrl = "/api/v1/users/" + customer.userId() + "/waitlist";
        assertThat(restTemplate.exchange(listUrl, HttpMethod.GET, auth, List.class).getBody()).hasSize(1);

        for (int i = 0; i < 2; i++) {
            assertThat(restTemplate.exchange(listUrl + "/" + providerId, HttpMethod.DELETE, auth, Void.class)
                    .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        }
        assertThat(restTemplate.exchange(listUrl, HttpMethod.GET, auth, List.class).getBody()).isEmpty();
    }

    @Test
    void rejectsAWindowThatIsOverEmptyOrForAnUnknownProviderAndAnotherUsersList() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "bad-wait-" + runId + "@example.com");
        Registered other = TestAuth.registerCustomer(restTemplate, "bad-wait-other-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "bad-wait-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Bad Wait Salon " + runId);

        Instant past = Instant.now().minus(1, ChronoUnit.DAYS);
        assertThat(join(customer, providerId, Map.of("to", past.toString())).getStatusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
        Instant later = Instant.now().plus(2, ChronoUnit.DAYS);
        assertThat(join(customer, providerId, Map.of("from", later.toString(), "to",
                later.minus(1, ChronoUnit.HOURS).toString())).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(join(customer, UUID.randomUUID(), null).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Someone else's list is off limits.
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/users/" + customer.userId() + "/waitlist",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(other.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    private boolean toldATimeOpened(String email) {
        return capturedEmails.sent.stream().anyMatch(e -> e.toEmail().equals(email)
                && e.subject().equals("A time just opened up"));
    }

    private ResponseEntity<Map> join(Registered customer, UUID providerId, Map<String, String> body) {
        return restTemplate.exchange("/api/v1/users/" + customer.userId() + "/waitlist/" + providerId,
                HttpMethod.PUT, new HttpEntity<>(body, TestAuth.authHeaders(customer.accessToken())), Map.class);
    }

    private UUID bookNewSlot(Registered owner, Registered customer, UUID providerId, UUID serviceId, Instant start) {
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slot = restTemplate.exchange("/api/v1/providers/" + providerId + "/availability-slots",
                HttpMethod.POST, new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(slot.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID slotId = UUID.fromString(slot.getBody().get("id").toString());
        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("25.00"));
        ResponseEntity<Map> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(booking.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(booking.getBody().get("id").toString());
    }

    private void cancel(Registered customer, UUID bookingId) {
        ResponseEntity<Map> cancelled = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(Map.of("reason", "Change of plans"),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(cancelled.getStatusCode()).isEqualTo(HttpStatus.OK);
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

    private UUID createService(Registered owner, UUID providerId) {
        var request = new CreateServiceRequest("Waitlist Service", 30, new BigDecimal("25.00"), "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
