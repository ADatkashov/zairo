package com.zairo.factory.payments;

import java.util.UUID;

/**
 * The success/failure URLs handed to the payment provider carry the booking's id, so the page the
 * customer lands on after paying ({@link PaymentReturnController}) can send them back to *that*
 * booking in the app. The id is the only thing added and it is a UUID this service itself generated.
 */
final class PaymentReturnUrls {

    private PaymentReturnUrls() {
    }

    /** {@code url} with {@code booking=<id>} appended; a blank url (return pages not configured) stays blank. */
    static String withBooking(String url, UUID bookingId) {
        if (url == null || url.isBlank()) {
            return url;
        }
        return url + (url.contains("?") ? "&" : "?") + "booking=" + bookingId;
    }
}
