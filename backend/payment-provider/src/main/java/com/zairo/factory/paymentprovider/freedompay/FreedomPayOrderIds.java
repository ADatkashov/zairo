package com.zairo.factory.paymentprovider.freedompay;

import java.util.Optional;
import java.util.UUID;

/**
 * The {@code pg_order_id} format {@link FreedomPayProvider} mints and a
 * webhook handler parses back — {@code "booking-payment:<paymentId>"} today
 * ({@code payments.Payment}'s id). Kept in one place so the write side
 * ({@code FreedomPayProvider.baseFields}) and the read side ({@code
 * payments.PaymentWebhookProcessor}) can't drift out of sync — see
 * ADR-0006's Webhook Architecture for why the format exists at all (routing
 * a webhook to the right domain object without an ambiguous lookup across
 * two tables sharing the UUID space).
 */
public final class FreedomPayOrderIds {

    private static final String BOOKING_PAYMENT_PREFIX = "booking-payment:";

    private FreedomPayOrderIds() {
    }

    public static String forBookingPayment(UUID paymentId) {
        return BOOKING_PAYMENT_PREFIX + paymentId;
    }

    public static Optional<UUID> parseBookingPaymentId(String orderId) {
        if (orderId == null || !orderId.startsWith(BOOKING_PAYMENT_PREFIX)) {
            return Optional.empty();
        }
        try {
            return Optional.of(UUID.fromString(orderId.substring(BOOKING_PAYMENT_PREFIX.length())));
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
