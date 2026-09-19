package com.zairo.factory.payments;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class BusinessPayoutDtos {

    private BusinessPayoutDtos() {
    }

    public record PayoutResponse(
            UUID id,
            UUID bookingId,
            UUID paymentId,
            UUID providerId,
            @Schema(example = "13500.00") BigDecimal amount,
            @Schema(example = "KZT") String currency,
            BusinessPayoutStatus status,
            @Schema(description = "Whatever actually moved the money — a manual bank transfer reference today. "
                    + "Only set once status is PROCESSING or PAID.")
            String providerReference,
            @Schema(description = "Only set when status is FAILED.") String failureReason,
            Instant createdAt,
            @Schema(description = "Only set once status is PAID.") Instant settledAt) {
        static PayoutResponse from(BusinessPayout payout) {
            return new PayoutResponse(payout.getId(), payout.getBookingId(), payout.getPaymentId(),
                    payout.getProviderId(), payout.getAmount(), payout.getCurrency(), payout.getStatus(),
                    payout.getProviderReference(), payout.getFailureReason(), payout.getCreatedAt(),
                    payout.getSettledAt());
        }
    }

    public record MarkPaidRequest(
            @Schema(description = "A bank transfer reference or other proof the transfer actually happened — "
                    + "free text, never validated for shape (see BusinessPayout.providerReference's own doc "
                    + "comment).", example = "kaspi-transfer-2026-09-19-A1B2")
            String providerReference) {
    }

    public record MarkFailedRequest(@Schema(example = "Business's bank details are invalid") String reason) {
    }
}
