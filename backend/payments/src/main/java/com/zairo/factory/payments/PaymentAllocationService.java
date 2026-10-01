package com.zairo.factory.payments;

import java.time.Instant;
import org.springframework.stereotype.Service;

/**
 * Creates the {@link PaymentAllocation} for a payment the moment it
 * succeeds — called from both places a {@code Payment} can reach
 * {@link PaymentStatus#SUCCEEDED} ({@code PaymentsService.charge}'s
 * synchronous/mock path and {@code PaymentWebhookProcessor.applyTransition}'s
 * webhook path), so the split is computed exactly once regardless of which
 * provider confirmed the charge — see ADR-0007.
 *
 * <p>Idempotent: a payment that already has an allocation (e.g. a duplicate
 * webhook delivery that reached this after the status guard elsewhere
 * already made the transition a no-op) is left alone rather than getting a
 * second row racing the unique {@code payment_id} primary key.
 */
@Service
class PaymentAllocationService {

    private final PaymentAllocationRepository allocationRepository;
    private final CommissionCalculator commissionCalculator;

    PaymentAllocationService(PaymentAllocationRepository allocationRepository,
            CommissionCalculator commissionCalculator) {
        this.allocationRepository = allocationRepository;
        this.commissionCalculator = commissionCalculator;
    }

    void ensureAllocation(Payment payment) {
        if (allocationRepository.findByPaymentId(payment.getId()).isPresent()) {
            return;
        }
        CommissionCalculator.Split split = commissionCalculator.split(payment.getAmount(), payment.getCurrency());
        PaymentAllocation allocation = new PaymentAllocation(payment.getId(), payment.getAmount(),
                split.businessAmount(), split.platformFee(), payment.getCurrency(), split.rate(), Instant.now());
        allocationRepository.save(allocation);
    }
}
