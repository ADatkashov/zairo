package com.zairo.factory.payments;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.UUID;
import org.junit.jupiter.api.Test;

class PaymentReturnUrlsTest {

    private static final UUID BOOKING = UUID.fromString("550e8400-e29b-41d4-a716-446655440000");

    @Test
    void appendsTheBookingIdAsAQueryParameter() {
        assertEquals("https://api.example/pay/return/success?booking=" + BOOKING,
                PaymentReturnUrls.withBooking("https://api.example/pay/return/success", BOOKING));
    }

    @Test
    void usesAnAmpersandWhenTheUrlAlreadyHasAQuery() {
        assertEquals("https://api.example/r?x=1&booking=" + BOOKING,
                PaymentReturnUrls.withBooking("https://api.example/r?x=1", BOOKING));
    }

    @Test
    void aBlankUrlStaysBlankBecauseReturnPagesAreNotConfigured() {
        assertEquals("", PaymentReturnUrls.withBooking("", BOOKING));
        assertNull(PaymentReturnUrls.withBooking(null, BOOKING));
    }
}
