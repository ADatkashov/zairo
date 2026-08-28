package com.zairo.factory.payments;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class PaymentDtos {

    private PaymentDtos() {
    }

    public record PaymentResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            @Schema(example = "25.00") BigDecimal amount,
            @Schema(example = "USD") String currency,
            PaymentStatus status,
            @Schema(description = "The mock payment provider's own reference id for this charge — the real "
                    + "idempotency key a real provider (Stripe, etc.) would key on.", example = "mock_ch_a1b2c3")
            String providerReference,
            @Schema(description = "Only set when status is FAILED.", example = "Card declined")
            String failureReason,
            @Schema(description = "Set when a refund attempt failed. Status stays SUCCEEDED in that case — "
                    + "this is money still owed back to the customer, not yet returned.", example = "Provider timeout")
            String refundFailureReason,
            Instant createdAt) {
        static PaymentResponse from(Payment payment) {
            return new PaymentResponse(payment.getId(), payment.getBookingId(), payment.getAmount(),
                    payment.getCurrency(), payment.getStatus(), payment.getProviderReference(),
                    payment.getFailureReason(), payment.getRefundFailureReason(), payment.getCreatedAt());
        }
    }
}
