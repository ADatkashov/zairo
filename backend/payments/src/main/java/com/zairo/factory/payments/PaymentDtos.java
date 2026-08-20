package com.zairo.factory.payments;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class PaymentDtos {

    private PaymentDtos() {
    }

    public record PaymentResponse(UUID id, UUID bookingId, BigDecimal amount, String currency,
            PaymentStatus status, String providerReference, String failureReason, Instant createdAt) {
        static PaymentResponse from(Payment payment) {
            return new PaymentResponse(payment.getId(), payment.getBookingId(), payment.getAmount(),
                    payment.getCurrency(), payment.getStatus(), payment.getProviderReference(),
                    payment.getFailureReason(), payment.getCreatedAt());
        }
    }
}
