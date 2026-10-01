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
import java.time.Instant;
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
    private final String successUrl;
    private final String failureUrl;

    public PaymentsService(PaymentRepository paymentRepository, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, BookingService bookingService,
            PaymentProvider paymentProvider, @Value("${payment.provider:mock}") String providerName,
            ProviderOwnership providerOwnership, ApplicationEventPublisher eventPublisher,
            PaymentAllocationService paymentAllocationService, BusinessPayoutRepository businessPayoutRepository,
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
        this.successUrl = successUrl;
        this.failureUrl = failureUrl;
    }

    /**
     * One payment per booking for now — full totalPrice, not a partial
     * deposit percentage. Splitting "deposit vs full payment" is a
     * business policy decision deferred until there's a real product
     * requirement for it (see SESSION_NOTES.md).
     *
     * <p>A booking whose only existing payment is FAILED retries against
     * that <em>same</em> row rather than inserting a new one — both
     * because {@code booking_id} is unique on the payment table (a second
     * insert would 500) and, more importantly, because reusing the row
     * keeps {@code paymentId} stable across retries, which is exactly the
     * idempotency key {@link PaymentProvider} promises a real provider
     * (see its doc comment) — minting a fresh id per retry would silently
     * defeat that guarantee. A FAILED retry never trips the status guard
     * below: {@code BookingService.cancelUnpaidBooking}'s own doc comment
     * confirms the booking stays PENDING_PAYMENT through exactly this case.
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

        Payment payment = paymentRepository.findByBookingId(bookingId).map(existing -> {
            if (existing.getStatus() != PaymentStatus.FAILED) {
                throw new PaymentConflictException("Booking already has a payment: " + bookingId);
            }
            return existing;
        }).orElseGet(() -> {
            // The booking's own currency, not an independently configured
            // default — see Money migration notes (SESSION_NOTES.md): two
            // separately-configured "USD" defaults that happened to agree
            // were a real latent bug (they could silently diverge), not a
            // feature.
            return paymentRepository.save(new Payment(UUID.randomUUID(), bookingId, booking.getTotalPrice(),
                    booking.getCurrency(), providerName, Instant.now()));
        });

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
                paymentAllocationService.ensureAllocation(payment);
                bookingService.confirmAfterPayment(payment.getBookingId());
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

        PaymentProvider.RefundResult result = paymentProvider.refund(payment.getId(), payment.getProviderReference(),
                payment.getAmount());
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
