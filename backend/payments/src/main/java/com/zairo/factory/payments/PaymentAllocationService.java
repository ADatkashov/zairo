package com.zairo.factory.payments;

import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.BookingRepository;
import java.math.BigDecimal;
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
    private final CommissionRateService commissionRateService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;

    PaymentAllocationService(PaymentAllocationRepository allocationRepository,
            CommissionRateService commissionRateService, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository) {
        this.allocationRepository = allocationRepository;
        this.commissionRateService = commissionRateService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
    }

    void ensureAllocation(Payment payment) {
        if (allocationRepository.findByPaymentId(payment.getId()).isPresent()) {
            return;
        }
        // The rate in force *right now* is snapshotted on the allocation — a
        // later change in the admin settings never rewrites past payments.
        BigDecimal rate = bookingRepository.findById(payment.getBookingId())
                .flatMap(b -> availabilitySlotRepository.findById(b.getAvailabilitySlotId()))
                .map(slot -> commissionRateService.rateForProvider(slot.getProviderId()))
                .orElse(BigDecimal.ZERO);
        CommissionCalculator.Split split = CommissionCalculator.split(payment.getAmount(), payment.getCurrency(),
                rate);
        PaymentAllocation allocation = new PaymentAllocation(payment.getId(), payment.getAmount(),
                split.businessAmount(), split.platformFee(), payment.getCurrency(), split.rate(), Instant.now());
        allocationRepository.save(allocation);
    }
}
