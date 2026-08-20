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
 * Against a real Postgres (Testcontainers): create a booking, pay for it
 * (through the mock PaymentProvider — always succeeds), verify it shows up,
 * reject a second payment attempt, then refund and verify the refund
 * guardrail (can't refund twice).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class PaymentsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void paysForABookingThenRefundsIt() {
        String runId = UUID.randomUUID().toString();
        UUID customerId = createUser("pay-customer-" + runId + "@example.com", "Pay Customer");
        UUID ownerId = createUser("pay-owner-" + runId + "@example.com", "Pay Owner");

        var providerRequest = new CreateProviderRequest(ownerId, "Payment Test Salon " + runId, "beauty");
        Map<?, ?> provider = restTemplate.postForEntity("/api/v1/providers", providerRequest, Map.class).getBody();
        UUID providerId = UUID.fromString(provider.get("id").toString());

        var serviceRequest = new CreateServiceRequest("Pay Service", 30, new BigDecimal("35.00"), "USD");
        Map<?, ?> service = restTemplate
                .postForEntity("/api/v1/providers/" + providerId + "/services", serviceRequest, Map.class).getBody();
        UUID serviceId = UUID.fromString(service.get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        Map<?, ?> slot = restTemplate
                .postForEntity("/api/v1/providers/" + providerId + "/availability-slots", slotRequest, Map.class)
                .getBody();
        UUID slotId = UUID.fromString(slot.get("id").toString());

        var bookingRequest = new CreateBookingRequest(customerId, serviceId, slotId, new BigDecimal("35.00"));
        Map<?, ?> booking = restTemplate.postForEntity("/api/v1/bookings", bookingRequest, Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());

        // No payment yet.
        ResponseEntity<Map> checkBefore = restTemplate.getForEntity("/api/v1/bookings/" + bookingId + "/payments",
                Map.class);
        assertThat(checkBefore.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // Charge — mock provider always succeeds.
        ResponseEntity<Map> payResponse = restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments",
                null, Map.class);
        assertThat(payResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(payResponse.getBody().get("status")).isEqualTo("SUCCEEDED");
        assertThat(payResponse.getBody().get("amount")).isEqualTo(35.00);
        UUID paymentId = UUID.fromString(payResponse.getBody().get("id").toString());

        // A second payment attempt on the same booking is rejected.
        ResponseEntity<Map> duplicatePay = restTemplate.postForEntity(
                "/api/v1/bookings/" + bookingId + "/payments", null, Map.class);
        assertThat(duplicatePay.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Refund succeeds.
        ResponseEntity<Map> refundResponse = restTemplate.postForEntity(
                "/api/v1/payments/" + paymentId + "/refund", null, Map.class);
        assertThat(refundResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(refundResponse.getBody().get("status")).isEqualTo("REFUNDED");

        // A second refund attempt is rejected — already refunded, not SUCCEEDED.
        ResponseEntity<Map> duplicateRefund = restTemplate.postForEntity(
                "/api/v1/payments/" + paymentId + "/refund", null, Map.class);
        assertThat(duplicateRefund.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    private UUID createUser(String email, String displayName) {
        var request = new CreateUserRequest(email, "+1000000000", displayName, UserRole.CUSTOMER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
