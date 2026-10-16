package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providerinsights.WeeklyBusinessReportService;
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

/** "Your week in numbers": a business with bookings in the week is emailed its figures, a quiet one is not. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class})
class WeeklyBusinessReportApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

    @Autowired
    private WeeklyBusinessReportService reportService;

    @Test
    void aBusinessWithBookingsGetsItsWeekByEmailAndAQuietOneGetsNothing() {
        String runId = UUID.randomUUID().toString();
        String busyEmail = "week-busy-" + runId + "@example.com";
        String quietEmail = "week-quiet-" + runId + "@example.com";
        Registered busy = TestAuth.registerOwner(restTemplate, busyEmail);
        Registered quiet = TestAuth.registerOwner(restTemplate, quietEmail);
        Registered customer = TestAuth.registerCustomer(restTemplate, "week-customer-" + runId + "@example.com");
        UUID busyProvider = createProvider(busy, "Busy Week Salon " + runId);
        createProvider(quiet, "Quiet Week Salon " + runId);
        UUID serviceId = createService(busy, busyProvider, "Week Service", new BigDecimal("40.00"));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(busy, busyProvider, start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateBookingRequest(customer.userId(), serviceId, slotId,
                        new BigDecimal("40.00")), TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(booking.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // Looked at two days from now, the booking (tomorrow) is inside the past seven days.
        reportService.publishReports(Instant.now().plus(2, ChronoUnit.DAYS));

        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(busyEmail);
            assertThat(email.subject()).isEqualTo("Your week: Busy Week Salon " + runId);
            assertThat(email.body()).contains("Bookings: 1 (+1 vs the week before)").contains("No new reviews");
        });
        assertThat(capturedEmails.sent).noneSatisfy(email -> assertThat(email.toEmail()).isEqualTo(quietEmail));
    }

    @Test
    void theReportQuotesTheWeeksAverageRatingWhenGuestsReviewed() {
        String runId = UUID.randomUUID().toString();
        String ownerEmail = "week-rated-" + runId + "@example.com";
        Registered owner = TestAuth.registerOwner(restTemplate, ownerEmail);
        Registered customer = TestAuth.registerCustomer(restTemplate, "week-rater-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Rated Week Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Rated Service", new BigDecimal("40.00"));
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateBookingRequest(customer.userId(), serviceId, slotId,
                        new BigDecimal("40.00")), TestAuth.authHeaders(customer.accessToken())), Map.class);
        String bookingId = booking.getBody().get("id").toString();
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(restTemplate.exchange("/api/v1/bookings/" + bookingId + "/reviews", HttpMethod.POST,
                new HttpEntity<>(Map.of("rating", 4, "comment", "Good"),
                        TestAuth.authHeaders(customer.accessToken())), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.CREATED);

        reportService.publishReports(Instant.now().plus(2, ChronoUnit.DAYS));

        assertThat(capturedEmails.sent).anySatisfy(email -> {
            assertThat(email.toEmail()).isEqualTo(ownerEmail);
            assertThat(email.body()).contains("Rating: 4.0 (1 new)").contains("Completed: 1");
        });
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
}
