package com.zairo.factory.payments;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.booking.InvalidBookingStateException;
import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.paymentprovider.PaymentProvider.PaymentInitiation;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import com.zairo.factory.providers.ProviderOwnership;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PaymentsService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final BookingService bookingService;
    private final PaymentProvider paymentProvider;
    private final PaymentProviderName providerName;
    private final ProviderOwnership providerOwnership;
    private final ApplicationEventPublisher eventPublisher;
    private final PaymentAllocationService paymentAllocationService;
    private final BusinessPayoutRepository businessPayoutRepository;
    private final PaymentPartialRefundRepository partialRefundRepository;
    private final String successUrl;
    private final String failureUrl;

    public PaymentsService(PaymentRepository paymentRepository, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, BookingService bookingService,
            PaymentProvider paymentProvider, @Value("${payment.provider:mock}") String providerName,
            ProviderOwnership providerOwnership, ApplicationEventPublisher eventPublisher,
            PaymentAllocationService paymentAllocationService, BusinessPayoutRepository businessPayoutRepository,
            PaymentPartialRefundRepository partialRefundRepository,
            @Value("${payment.return.success-url:}") String successUrl,
            @Value("${payment.return.failure-url:}") String failureUrl) {
        this.paymentRepository = paymentRepository;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.bookingService = bookingService;
        this.paymentProvider = paymentProvider;
        this.providerName = PaymentProviderName.valueOf(providerName.toUpperCase());
        this.providerOwnership = providerOwnership;
        this.eventPublisher = eventPublisher;
        this.paymentAllocationService = paymentAllocationService;
        this.businessPayoutRepository = businessPayoutRepository;
        this.partialRefundRepository = partialRefundRepository;
        this.successUrl = successUrl;
        this.failureUrl = failureUrl;
    }

    /**
     * Create an online payment for a booking. If the booking has a deposit
     * requirement, the payment amount will be the deposit. Otherwise, it will
     * be the full booking amount.
     *
     * <p>Multiple payments can be created for a single booking (one online
     * payment for deposit, then later payments for balance via other methods).
     *
     * <p>A FAILED payment can be retried using the same payment row — keeps
     * paymentId stable across retries for idempotency with the provider.
     */
    @Transactional
    public Payment createPayment(UUID bookingId, UUID callerId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        requireCustomerOrProviderOwner(booking, callerId);

        if (booking.getStatus() != BookingStatus.PENDING_PAYMENT) {
            throw new InvalidBookingStateException("Booking is not awaiting payment: " + bookingId + " (status="
                    + booking.getStatus() + ")");
        }

        // Determine payment amount: if there's a deposit, charge the deposit; otherwise charge the full amount
        BigDecimal paymentAmount = booking.getDepositAmount().compareTo(BigDecimal.ZERO) > 0 ?
                booking.getDepositAmount() : booking.getTotalPrice();

        // Try to reuse a failed ONLINE payment for this booking
        List<Payment> existingPayments = paymentRepository.findAllByBookingId(bookingId);
        Payment payment = null;
        for (Payment existing : existingPayments) {
            if (existing.getStatus() == PaymentStatus.FAILED && existing.getPaymentMethod() == PaymentMethod.ONLINE) {
                payment = existing;
                break;
            }
        }

        if (payment == null) {
            // The customer already has a checkout open with the provider (PENDING, waiting for
            // the webhook): hand that payment back — same id, same checkoutUrl — instead of
            // minting a second payment and a second provider-side session. Without this a
            // double tap on "Pay" (or the app resuming a half-finished payment) could leave
            // two PENDING rows for one booking, and the customer able to pay twice.
            for (Payment existing : existingPayments) {
                if (existing.getStatus() == PaymentStatus.PENDING && existing.getPaymentMethod() == PaymentMethod.ONLINE) {
                    return existing;
                }
            }
            payment = paymentRepository.save(new Payment(UUID.randomUUID(), bookingId, paymentAmount,
                    booking.getCurrency(), providerName, PaymentMethod.ONLINE, Instant.now()));
        }

        charge(payment);
        return paymentRepository.save(payment);
    }

    /**
     * Restricted to the two parties involved: the booking's own customer, or
     * the owner of the provider the booking's slot belongs to — same check
     * as core {@code BookingController.getById} (see PR #57) and the
     * vertical booking {@code getBooking} methods (see PR #59), reused here
     * rather than reinvented. Authorization is resolved from the booking
     * referenced by {@code bookingId}, never from the payment row itself —
     * a payment has no owner of its own to trust.
     */
    public Payment getPaymentForBooking(UUID bookingId, UUID callerId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        requireCustomerOrProviderOwner(booking, callerId);

        return paymentRepository.findByBookingId(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "No payment for booking: " + bookingId));
    }

    /**
     * Record a payment made through a non-online method (cash, card at location, etc).
     * This is used by the business to record payments they received outside of ZAIRO.
     */
    @Transactional
    public Payment recordOfflinePayment(UUID bookingId, BigDecimal amount, PaymentMethod method, UUID callerId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        requireProviderOwner(booking, callerId);

        if (method == PaymentMethod.ONLINE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Use createPayment() for ONLINE payments");
        }

        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Payment amount must be positive");
        }

        // Create a payment record for this offline payment
        Payment payment = new Payment(UUID.randomUUID(), bookingId, amount, booking.getCurrency(),
                PaymentProviderName.MOCK, method, Instant.now());
        payment = paymentRepository.save(payment);

        // Immediately mark as succeeded since it's already been paid offline
        payment.markSucceeded(null, Instant.now());
        payment = paymentRepository.save(payment);

        // Update booking paid amount
        booking.recordPayment(amount);
        bookingRepository.save(booking);

        // If booking's deposit is now satisfied and status is still PENDING_PAYMENT, confirm it
        if (booking.getStatus() == BookingStatus.PENDING_PAYMENT && booking.hasDepositBeenPaid()) {
            bookingService.confirmAfterPayment(bookingId);
        }

        return payment;
    }

    private void requireProviderOwner(Booking booking, UUID callerId) {
        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Availability slot not found: " + booking.getAvailabilitySlotId()));
        providerOwnership.requireOwner(slot.getProviderId(), callerId);
    }

    /** See {@link #getPaymentForBooking} and {@code BookingController.getById}'s own doc comment. */
    private void requireCustomerOrProviderOwner(Booking booking, UUID callerId) {
        if (booking.getUserId().equals(callerId)) {
            return;
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Availability slot not found: " + booking.getAvailabilitySlotId()));
        providerOwnership.requireOwner(slot.getProviderId(), callerId);
    }

    /**
     * A declined/failed initiation and a provider-side exception (network
     * error, timeout) both leave the payment FAILED rather than letting the
     * exception propagate and roll back this transaction — losing the
     * just-persisted payment row would mint a new idempotency key on the
     * next retry (see createPayment's doc comment), silently defeating the
     * whole point of keying charges by paymentId.
     *
     * <p>A FAILED result here deliberately does <b>not</b> cancel the
     * booking — see {@code BookingService.cancelUnpaidBooking}'s doc
     * comment: the booking stays PENDING_PAYMENT so a retried charge (same
     * payment row) can still confirm it. Only {@link
     * PaymentProvider.InitiationStatus#SUCCEEDED} confirms the booking —
     * {@link PaymentProvider.InitiationStatus#PENDING} (a real, redirect-
     * based provider) confirms nothing yet: that's the webhook's job.
     */
    private void charge(Payment payment) {
        PaymentInitiation result;
        try {
            result = paymentProvider.createPayment(payment.getId(), payment.getAmount(), payment.getCurrency(),
                    "Factory booking payment", successUrl, failureUrl);
        } catch (RuntimeException e) {
            payment.markFailed("Payment provider error: " + e.getMessage(), Instant.now());
            return;
        }

        switch (result.status()) {
            case SUCCEEDED -> {
                payment.markSucceeded(result.providerPaymentId(), Instant.now());
                // Record the payment in the booking
                Booking booking = bookingRepository.findById(payment.getBookingId()).orElse(null);
                if (booking != null) {
                    booking.recordPayment(payment.getAmount());
                    bookingRepository.save(booking);
                }
                paymentAllocationService.ensureAllocation(payment);
                // Only confirm if deposit is fully paid (or no deposit required)
                if (booking != null && booking.hasDepositBeenPaid()) {
                    bookingService.confirmAfterPayment(payment.getBookingId());
                }
            }
            case FAILED -> payment.markFailed(result.failureReason(), Instant.now());
            case PENDING -> payment.markPending(result.providerPaymentId(), result.checkoutUrl(), Instant.now());
        }
    }

    // noRollbackFor: the BAD_GATEWAY branch below deliberately persists the
    // refund-failure fact on the payment row before throwing — a bare
    // @Transactional would roll that write back along with the exception
    // (ResponseStatusException is unchecked), silently undoing the whole
    // point of recording it.
    @Transactional(noRollbackFor = ResponseStatusException.class)
    public Payment refundPayment(UUID paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Payment not found: "
                        + paymentId));

        // REFUND_FAILED is retriable — see Payment.markRefundFailed's doc
        // comment ("refundable from this state too").
        if (payment.getStatus() != PaymentStatus.SUCCEEDED && payment.getStatus() != PaymentStatus.REFUND_FAILED) {
            throw new PaymentConflictException("Only a succeeded payment can be refunded: " + paymentId
                    + " (status=" + payment.getStatus() + ")");
        }

        // Once the business's share is PROCESSING/PAID, the money is
        // leaving (or has left) ZAIRO's control for a bank transfer this
        // codebase has no confirmed provider-side reversal for (ADR-0007,
        // Open Questions) — refunding the customer here would not claw
        // that back. Blocked, not silently allowed; see docs/PAYMENT_STATE_MACHINE.md
        // ("SETTLED -> REFUNDED only through a supported provider reversal").
        businessPayoutRepository.findByPaymentId(paymentId).ifPresent(payout -> {
            if (payout.getStatus() == BusinessPayoutStatus.PROCESSING || payout.getStatus() == BusinessPayoutStatus.PAID) {
                throw new PaymentConflictException("Cannot refund payment " + paymentId
                        + ": its business payout is already " + payout.getStatus()
                        + " — requires manual reconciliation, not a customer-facing refund");
            }
        });

        // Anything a cheaper replacement worker already returned (partially) is not refunded a second time.
        BigDecimal refundable = payment.getAmount().subtract(partialRefundRepository.totalForPayment(payment.getId()));
        PaymentProvider.RefundResult result = paymentProvider.refund(payment.getId(), payment.getProviderReference(),
                refundable);
        if (!result.succeeded()) {
            // Recorded on the row before throwing — a failed refund used to
            // be visible only in whatever caller's log line happened to
            // catch this exception (see BookingCancelledPaymentListener).
            // Now it's a durable, queryable fact on the payment itself:
            // still SUCCEEDED with a non-null refundFailureReason means
            // "money owed back, not yet returned."
            payment.markRefundFailed(result.failureReason(), Instant.now());
            paymentRepository.save(payment);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Refund failed: " + result.failureReason());
        }
        payment.markRefunded(Instant.now());
        Payment refunded = paymentRepository.save(payment);
        eventPublisher.publishEvent(new PaymentRefundedEvent(refunded.getId(), refunded.getBookingId(),
                refunded.getAmount(), refunded.getCurrency()));
        return refunded;
    }
}
