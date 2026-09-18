package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.PaymentProviderName;
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
            PaymentProviderName provider,
            @Schema(description = "The payment provider's own id for this charge (Freedom Pay's pg_payment_id, "
                    + "or the mock's synthetic mock_pi_... id) — the real idempotency key a real provider keys on.",
                    example = "mock_pi_a1b2c3")
            String providerReference,
            @Schema(description = "Redirect the customer here to complete payment. Only set while status is "
                    + "PENDING under a real (redirect-based) provider — null for the mock, and null again once "
                    + "the payment resolves either way.")
            String checkoutUrl,
            @Schema(description = "Only set when status is FAILED.", example = "Card declined")
            String failureReason,
            @Schema(description = "Set when the most recent refund attempt failed — status is REFUND_FAILED in "
                    + "that case, meaning this is money still owed back to the customer, not yet returned.",
                    example = "Provider timeout")
            String refundFailureReason,
            @Schema(description = "How many refund attempts have failed for this payment, ever (not reset by an "
                    + "eventual success).")
            int refundAttempts,
            Instant createdAt) {
        static PaymentResponse from(Payment payment) {
            return new PaymentResponse(payment.getId(), payment.getBookingId(), payment.getAmount(),
                    payment.getCurrency(), payment.getStatus(), payment.getProvider(),
                    payment.getProviderReference(), payment.getCheckoutUrl(), payment.getFailureReason(),
                    payment.getRefundFailureReason(), payment.getRefundAttempts(), payment.getCreatedAt());
        }
    }

    /** The platform admin's durable-refund-outbox visibility view — see PaymentAdminController. */
    public record RefundRequestResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID paymentId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            @Schema(example = "25.00") BigDecimal amount,
            @Schema(example = "USD") String currency,
            PaymentProviderName provider,
            PaymentRefundRequestStatus status,
            @Schema(description = "How many refund attempts this row has made, ever.") int attempts,
            @Schema(description = "When the worker will next attempt this row — null once terminal (SUCCEEDED/"
                    + "FAILED), or while a claim is actively PROCESSING it.")
            Instant nextAttemptAt,
            @Schema(description = "Set only while status is PROCESSING — a value older than 5 minutes means a "
                    + "worker most likely crashed mid-attempt and this row is eligible for reclaim.")
            Instant processingStartedAt,
            @Schema(description = "The most recent failure's message, if any.", example = "Freedom Pay returned "
                    + "pg_status=error")
            String lastError,
            Instant createdAt,
            Instant updatedAt) {
        static RefundRequestResponse from(PaymentRefundRequest request) {
            return new RefundRequestResponse(request.getId(), request.getPaymentId(), request.getBookingId(),
                    request.getAmount(), request.getCurrency(), request.getProvider(), request.getStatus(),
                    request.getAttempts(), request.getNextAttemptAt(), request.getProcessingStartedAt(),
                    request.getLastError(), request.getCreatedAt(), request.getUpdatedAt());
        }
    }
}
