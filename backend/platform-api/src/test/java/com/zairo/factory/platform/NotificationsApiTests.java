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
 * Against a real Postgres (Testcontainers): confirming a booking populates
 * the customer's in-app notification feed (see
 * {@code BookingNotificationListener.onBookingConfirmed}), and the
 * list/unread-count/mark-read/mark-all-read endpoints behave — plus the
 * same owner-only enforcement as {@code FavoritesApiTests}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class NotificationsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    private Registered confirmABookingAndReturnCustomer(String runId) {
        Registered customer = TestAuth.registerCustomer(restTemplate, "notif-customer-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "notif-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Notification Test Salon " + runId,
                "beauty");
        ResponseEntity<Map> providerResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString(providerResponse.getBody().get("id").toString());

        var serviceRequest = new CreateServiceRequest("Notif Service", 30, new BigDecimal("15.00"), "USD");
        ResponseEntity<Map> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        UUID serviceId = UUID.fromString(serviceResponse.getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> slotResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID slotId = UUID.fromString(slotResponse.getBody().get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("15.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments", null, Map.class);

        return customer;
    }

    @Test
    void confirmingABookingNotifiesTheCustomerAndMarkingItReadClearsTheUnreadCount() {
        String runId = UUID.randomUUID().toString();
        Registered customer = confirmABookingAndReturnCustomer(runId);
        UUID customerId = customer.userId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken()));

        ResponseEntity<Map[]> listResponse = restTemplate.exchange("/api/v1/users/" + customerId + "/notifications",
                HttpMethod.GET, customerAuth, Map[].class);
        assertThat(listResponse.getBody()).hasSize(1);
        Map<?, ?> notification = listResponse.getBody()[0];
        assertThat(notification.get("type")).isEqualTo("BOOKING_CONFIRMED");
        assertThat(notification.get("read")).isEqualTo(false);
        UUID notificationId = UUID.fromString(notification.get("id").toString());

        ResponseEntity<Map> countBefore = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/notifications/unread-count", HttpMethod.GET, customerAuth,
                Map.class);
        assertThat(((Number) countBefore.getBody().get("count")).longValue()).isEqualTo(1L);

        ResponseEntity<Void> markReadResponse = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/notifications/" + notificationId + "/read", HttpMethod.POST,
                customerAuth, Void.class);
        assertThat(markReadResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<Map> countAfter = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/notifications/unread-count", HttpMethod.GET, customerAuth,
                Map.class);
        assertThat(((Number) countAfter.getBody().get("count")).longValue()).isEqualTo(0L);
    }

    @Test
    void markAllReadClearsEveryUnreadNotification() {
        String runId = UUID.randomUUID().toString();
        Registered customer = confirmABookingAndReturnCustomer(runId);
        UUID customerId = customer.userId();
        var customerAuth = new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken()));

        ResponseEntity<Void> markAllReadResponse = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/notifications/read-all", HttpMethod.POST, customerAuth,
                Void.class);
        assertThat(markAllReadResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<Map> countAfter = restTemplate.exchange(
                "/api/v1/users/" + customerId + "/notifications/unread-count", HttpMethod.GET, customerAuth,
                Map.class);
        assertThat(((Number) countAfter.getBody().get("count")).longValue()).isEqualTo(0L);
    }

    @Test
    void aUserCannotReadAnotherUsersNotifications() {
        String runId = UUID.randomUUID().toString();
        UUID customerId = confirmABookingAndReturnCustomer(runId).userId();
        Registered otherCustomer = TestAuth.registerCustomer(restTemplate,
                "notif-other-" + runId + "@example.com");
        var otherAuth = new HttpEntity<>(null, TestAuth.authHeaders(otherCustomer.accessToken()));

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/users/" + customerId + "/notifications",
                HttpMethod.GET, otherAuth, Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }
}
