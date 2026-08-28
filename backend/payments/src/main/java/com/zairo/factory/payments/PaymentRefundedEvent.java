package com.zairo.factory.payments;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Published after a refund actually succeeds — see ADR-0002 (in-process
 * domain events instead of Kafka). Not published on {@code REFUND_FAILED}:
 * that's a support/finance-visibility concern (see {@code
 * PaymentAdminController}), not something to email the customer about
 * automatically — telling a customer "we tried and failed to refund you"
 * without a human already involved would just cause alarm.
 */
public record PaymentRefundedEvent(UUID paymentId, UUID bookingId, BigDecimal amount, String currency) {
}
