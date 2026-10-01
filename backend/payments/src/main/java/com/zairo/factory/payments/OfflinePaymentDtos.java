package com.zairo.factory.payments;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.UUID;

public final class OfflinePaymentDtos {

    private OfflinePaymentDtos() {
    }

    public record RecordPaymentRequest(
            @NotNull @DecimalMin("0.01") @Schema(description = "Amount paid", example = "15000.00") BigDecimal amount,
            @NotNull @Schema(description = "How the payment was made") PaymentMethod method) {
    }

    public record PaymentResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            @Schema(example = "15000.00") BigDecimal amount,
            @Schema(example = "KZT") String currency,
            PaymentStatus status,
            PaymentMethod paymentMethod,
            String checkoutUrl) {
        static PaymentResponse from(Payment payment) {
            return new PaymentResponse(payment.getId(), payment.getBookingId(), payment.getAmount(),
                    payment.getCurrency(), payment.getStatus(), payment.getPaymentMethod(),
                    payment.getCheckoutUrl());
        }
    }
}
