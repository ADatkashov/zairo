package com.zairo.factory.paymentprovider.freedompay;

import java.util.Optional;
import java.util.UUID;

/**
 * The {@code pg_order_id} formats {@link FreedomPayProvider} mints and a
 * webhook handler parses back — {@code "booking-payment:<paymentId>"}
 * ({@code payments.Payment}'s id) or {@code
 * "subscription-charge:<chargeId>"} ({@code subscriptions.SubscriptionCharge}'s
 * id). Kept in one place so the write side ({@code
 * FreedomPayProvider.createPayment}/{@code createRecurringPayment}) and the
 * read side ({@code payments.PaymentWebhookProcessor}) can't drift out of
 * sync — see ADR-0006's Webhook Architecture for why the format exists at
 * all (routing a webhook to the right domain object, across two different
 * tables/id-spaces sharing FreedomPay's one merchant-configured notify URL,
 * without an ambiguous lookup).
 *
 * <p>Before Phase 0 stabilization, {@code createRecurringPayment} (the
 * subscription-upgrade charge) reused {@code forBookingPayment}'s prefix
 * with a {@code SubscriptionCharge} id in place of a {@code Payment} id —
 * the webhook then looked that id up in {@code payments.PaymentRepository}
 * (a different table), which could never find it, so the webhook was always
 * rejected as "unknown payment" and a real-provider PRO upgrade could never
 * actually activate. Each order-id shape now carries its own type.
 */
public final class FreedomPayOrderIds {

    private static final String BOOKING_PAYMENT_PREFIX = "booking-payment:";
    private static final String SUBSCRIPTION_CHARGE_PREFIX = "subscription-charge:";

    private FreedomPayOrderIds() {
    }

    public static String forBookingPayment(UUID paymentId) {
        return BOOKING_PAYMENT_PREFIX + paymentId;
    }

    public static Optional<UUID> parseBookingPaymentId(String orderId) {
        return parse(orderId, BOOKING_PAYMENT_PREFIX);
    }

    public static String forSubscriptionCharge(UUID chargeId) {
        return SUBSCRIPTION_CHARGE_PREFIX + chargeId;
    }

    public static Optional<UUID> parseSubscriptionChargeId(String orderId) {
        return parse(orderId, SUBSCRIPTION_CHARGE_PREFIX);
    }

    private static Optional<UUID> parse(String orderId, String prefix) {
        if (orderId == null || !orderId.startsWith(prefix)) {
            return Optional.empty();
        }
        try {
            return Optional.of(UUID.fromString(orderId.substring(prefix.length())));
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
