package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * The page the payment provider sends the customer's browser to after paying: it is public, opens the
 * app through its deep link, and reflects nothing but a booking id that parses as a UUID.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class})
class PaymentReturnApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void theSuccessPageIsPublicAndOpensTheAppOnTheBooking() {
        UUID booking = UUID.randomUUID();

        ResponseEntity<String> response = restTemplate.getForEntity("/pay/return/success?booking=" + booking,
                String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getContentType().isCompatibleWith(MediaType.TEXT_HTML)).isTrue();
        assertThat(response.getBody())
                .contains("zairo://app/payment-result?status=success&booking=" + booking)
                .contains("zairo://app/payment-result?status=success&amp;booking=" + booking);
    }

    @Test
    void theFailurePageAndAPostRedirectBothWork() {
        UUID booking = UUID.randomUUID();

        ResponseEntity<String> failure = restTemplate.getForEntity("/pay/return/failure?booking=" + booking,
                String.class);
        assertThat(failure.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(failure.getBody()).contains("zairo://app/payment-result?status=failure&booking=" + booking);

        // Some providers send the customer back with a POST.
        ResponseEntity<String> post = restTemplate.exchange("/pay/return/success?booking=" + booking,
                HttpMethod.POST, null, String.class);
        assertThat(post.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(post.getBody()).contains("zairo://app/payment-result?status=success&booking=" + booking);
    }

    @Test
    void aMissingOrMalformedBookingIdIsNeverReflected() {
        ResponseEntity<String> none = restTemplate.getForEntity("/pay/return/success", String.class);
        assertThat(none.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(none.getBody()).contains("zairo://app/payment-result?status=success\"")
                .doesNotContain("booking=");

        String attack = "\"><script>alert(1)</script>";
        ResponseEntity<String> hostile = restTemplate.getForEntity(
                "/pay/return/success?booking={b}", String.class, attack);
        assertThat(hostile.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(hostile.getBody()).doesNotContain("alert(1)").doesNotContain("booking=");
    }

    @Test
    void anUnknownOutcomeIsNotFound() {
        ResponseEntity<String> response = restTemplate.getForEntity("/pay/return/anything", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
