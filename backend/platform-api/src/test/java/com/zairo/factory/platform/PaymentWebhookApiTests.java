package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import com.zairo.factory.payments.Payment;
import com.zairo.factory.payments.PaymentRepository;
import com.zairo.factory.payments.PaymentStatus;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;
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
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

/**
 * Against a real Postgres (Testcontainers): the Freedom Pay webhook endpoint
 * end to end, signed the same way {@code FreedomPaySignature} signs (a
 * standalone MD5 reimplementation here — that class is package-private in
 * {@code payment-provider}) using this app's actual (empty, unset in tests)
 * {@code payment.freedompay.secret-key} and default {@code result.php}
 * script name, so these tests exercise the real {@code
 * FreedomPayWebhookVerifier} bean, not a stub. A {@code Payment} row is
 * inserted directly in PENDING (bypassing the always-synchronous mock
 * provider, which never leaves anything for a webhook to resolve) to put
 * the system in the state a real Freedom Pay checkout would.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class PaymentWebhookApiTests {

    private static final String SCRIPT_NAME = "result.php";
    private static final String SECRET_KEY = "";

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private BookingRepository bookingRepository;

    @Test
    void aValidWebhookConfirmsThePendingPaymentAndItsBooking() {
        String runId = UUID.randomUUID().toString();
        UUID bookingId = createPendingBooking(runId, new BigDecimal("25.00"));
        UUID paymentId = createPendingPayment(bookingId, new BigDecimal("25.00"), "USD");

        ResponseEntity<String> response = postWebhook(signedFields(paymentId, "25.00", "USD", "1"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("<pg_status>ok</pg_status>");

        assertThat(paymentRepository.findById(paymentId).orElseThrow().getStatus())
                .isEqualTo(PaymentStatus.SUCCEEDED);
        assertThat(bookingRepository.findById(bookingId).orElseThrow().getStatus())
                .isEqualTo(BookingStatus.CONFIRMED);
    }

    @Test
    void aDuplicateWebhookDeliveryDoesNotReprocess() {
        String runId = UUID.randomUUID().toString();
        UUID bookingId = createPendingBooking(runId, new BigDecimal("30.00"));
        UUID paymentId = createPendingPayment(bookingId, new BigDecimal("30.00"), "USD");
        MultiValueMap<String, String> fields = signedFields(paymentId, "30.00", "USD", "1");

        assertThat(postWebhook(fields).getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(postWebhook(fields).getStatusCode()).isEqualTo(HttpStatus.OK);

        assertThat(paymentRepository.findById(paymentId).orElseThrow().getStatus())
                .isEqualTo(PaymentStatus.SUCCEEDED);
        assertThat(bookingRepository.findById(bookingId).orElseThrow().getStatus())
                .isEqualTo(BookingStatus.CONFIRMED);
    }

    @Test
    void aTamperedSignatureIsRejectedWithoutChangingAnyState() {
        String runId = UUID.randomUUID().toString();
        UUID bookingId = createPendingBooking(runId, new BigDecimal("18.00"));
        UUID paymentId = createPendingPayment(bookingId, new BigDecimal("18.00"), "USD");

        MultiValueMap<String, String> fields = signedFields(paymentId, "18.00", "USD", "1");
        fields.set("pg_sig", "0000000000000000000000000000000");

        ResponseEntity<String> response = postWebhook(fields);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);

        assertThat(paymentRepository.findById(paymentId).orElseThrow().getStatus()).isEqualTo(PaymentStatus.CREATED);
        assertThat(bookingRepository.findById(bookingId).orElseThrow().getStatus())
                .isEqualTo(BookingStatus.PENDING_PAYMENT);
    }

    @Test
    void aSuccessWebhookForAnAlreadyCancelledBookingIsAutoRefundedInsteadOfConfirmed() {
        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "webhook-late-" + runId + "@example.com");
        UUID bookingId = createPendingBooking(customer, runId, new BigDecimal("12.00"));
        UUID paymentId = createPendingPayment(bookingId, new BigDecimal("12.00"), "USD");

        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(bookingRepository.findById(bookingId).orElseThrow().getStatus())
                .isEqualTo(BookingStatus.CANCELLED);

        ResponseEntity<String> response = postWebhook(signedFields(paymentId, "12.00", "USD", "1"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);

        assertThat(paymentRepository.findById(paymentId).orElseThrow().getStatus()).isEqualTo(PaymentStatus.REFUNDED);
        assertThat(bookingRepository.findById(bookingId).orElseThrow().getStatus()).isEqualTo(BookingStatus.CANCELLED);
    }

    private UUID createPendingBooking(String runId, BigDecimal price) {
        Registered customer = TestAuth.registerCustomer(restTemplate, "webhook-cust-" + runId + "@example.com");
        return createPendingBooking(customer, runId, price);
    }

    private UUID createPendingBooking(Registered customer, String runId, BigDecimal price) {
        Registered owner = TestAuth.registerOwner(restTemplate, "webhook-owner-" + runId + "@example.com");
        var providerRequest = new CreateProviderRequest(owner.userId(), "Webhook Salon " + runId, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);

        var serviceRequest = new CreateServiceRequest("Webhook Service", 30, price, "USD");
        UUID serviceId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class).getBody().get("id").toString());

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId
                + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, price);
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        return UUID.fromString(booking.get("id").toString());
    }

    /**
     * Bypasses the always-synchronous mock provider — a real Freedom Pay
     * checkout leaves exactly this: a row with no terminal outcome yet
     * ({@code markPending} is package-private to {@code payments}, so this
     * stays CREATED rather than PENDING — the webhook processor treats both
     * identically, see PaymentWebhookProcessor.applyTransition's guard).
     */
    private UUID createPendingPayment(UUID bookingId, BigDecimal amount, String currency) {
        Booking booking = bookingRepository.findById(bookingId).orElseThrow();
        Payment payment = new Payment(UUID.randomUUID(), booking.getId(), amount, currency,
                PaymentProviderName.FREEDOMPAY, Instant.now());
        return paymentRepository.save(payment).getId();
    }

    private ResponseEntity<String> postWebhook(MultiValueMap<String, String> form) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        return restTemplate.postForEntity("/webhooks/payments/freedompay", new HttpEntity<>(form, headers),
                String.class);
    }

    private MultiValueMap<String, String> signedFields(UUID paymentId, String amount, String currency,
            String pgResult) {
        Map<String, String> fields = new TreeMap<>();
        fields.put("pg_order_id", "booking-payment:" + paymentId);
        fields.put("pg_payment_id", "fp_" + paymentId);
        fields.put("pg_amount", amount);
        fields.put("pg_currency", currency);
        fields.put("pg_result", pgResult);
        String signature = computeSignature(SCRIPT_NAME, fields, SECRET_KEY);

        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        fields.forEach(form::add);
        form.add("pg_sig", signature);
        return form;
    }

    /** Reimplements FreedomPaySignature.compute (package-private in payment-provider) against known test inputs. */
    private static String computeSignature(String scriptName, Map<String, String> fields, String secretKey) {
        SortedMap<String, String> sorted = new TreeMap<>(fields);
        StringBuilder toSign = new StringBuilder(scriptName);
        for (String value : sorted.values()) {
            toSign.append(';').append(value == null ? "" : value);
        }
        toSign.append(';').append(secretKey);
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] hash = digest.digest(toSign.toString().getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
