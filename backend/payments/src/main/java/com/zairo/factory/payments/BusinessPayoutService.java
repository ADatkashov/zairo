package com.zairo.factory.payments;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Creates and progresses a booking's {@link BusinessPayout} — see that
 * class's own doc comment and {@code docs/adr/0007-marketplace-commission-and-settlement.md}.
 * Mutation ({@link #markProcessing}/{@link #markPaid}/{@link #markFailed})
 * is PLATFORM_ADMIN-only, enforced by the controllers that call this — see
 * {@code BusinessPayoutAdminController}, mirroring how {@code
 * PaymentsService.refundPayment} itself has no authorization logic (that's
 * the controller's job, see {@code PaymentsController.refund}).
 */
@Service
public class BusinessPayoutService {

    private static final Logger log = LoggerFactory.getLogger(BusinessPayoutService.class);

    private final BusinessPayoutRepository payoutRepository;
    private final PaymentRepository paymentRepository;
    private final PaymentAllocationRepository allocationRepository;

    BusinessPayoutService(BusinessPayoutRepository payoutRepository, PaymentRepository paymentRepository,
            PaymentAllocationRepository allocationRepository) {
        this.payoutRepository = payoutRepository;
        this.paymentRepository = paymentRepository;
        this.allocationRepository = allocationRepository;
    }

    /**
     * Called only once a booking is {@code COMPLETED} — see {@code
     * BookingCompletedPayoutListener}. Idempotent: a booking that already
     * has a payout row (e.g. a re-delivered event) is left alone rather
     * than getting a second row racing {@code booking_id}'s unique
     * constraint.
     *
     * <p>A booking with no SUCCEEDED payment (shouldn't normally happen —
     * {@code BookingService.completeBooking} only accepts a CONFIRMED
     * booking, which requires a SUCCEEDED payment to have reached CONFIRMED
     * in the first place) or no allocation yet is logged and skipped, not
     * thrown — a payout listener failing loudly would roll back the
     * booking-completion transaction it's decoupled from for a case that
     * should be unreachable, not a customer-facing error.
     */
    @Transactional
    public void createPayableForCompletedBooking(UUID bookingId, UUID providerId) {
        if (payoutRepository.findByBookingId(bookingId).isPresent()) {
            return;
        }

        Optional<Payment> maybePayment = paymentRepository.findByBookingId(bookingId);
        if (maybePayment.isEmpty() || maybePayment.get().getStatus() != PaymentStatus.SUCCEEDED) {
            log.warn("Booking {} completed but has no SUCCEEDED payment — no payout created", bookingId);
            return;
        }
        Payment payment = maybePayment.get();

        Optional<PaymentAllocation> maybeAllocation = allocationRepository.findByPaymentId(payment.getId());
        if (maybeAllocation.isEmpty()) {
            log.warn("Booking {} completed but payment {} has no allocation yet — no payout created", bookingId,
                    payment.getId());
            return;
        }
        PaymentAllocation allocation = maybeAllocation.get();

        BusinessPayout payout = new BusinessPayout(UUID.randomUUID(), bookingId, payment.getId(), providerId,
                allocation.getBusinessAmount(), allocation.getCurrency(), Instant.now());
        payoutRepository.save(payout);
    }

    @Transactional
    public BusinessPayout markProcessing(UUID payoutId) {
        BusinessPayout payout = require(payoutId);
        payout.markProcessing(Instant.now());
        return payoutRepository.save(payout);
    }

    @Transactional
    public BusinessPayout markPaid(UUID payoutId, String providerReference) {
        BusinessPayout payout = require(payoutId);
        payout.markPaid(providerReference, Instant.now());
        return payoutRepository.save(payout);
    }

    @Transactional
    public BusinessPayout markFailed(UUID payoutId, String reason) {
        BusinessPayout payout = require(payoutId);
        payout.markFailed(reason, Instant.now());
        return payoutRepository.save(payout);
    }

    private BusinessPayout require(UUID payoutId) {
        return payoutRepository.findById(payoutId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Payout not found: " + payoutId));
    }
}
