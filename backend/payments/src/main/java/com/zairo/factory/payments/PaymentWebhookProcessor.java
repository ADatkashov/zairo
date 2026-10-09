package com.zairo.factory.payments;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import com.zairo.factory.paymentprovider.freedompay.FreedomPayOrderIds;
import com.zairo.factory.paymentprovider.freedompay.FreedomPayWebhookVerifier.VerifiedWebhook;
import com.zairo.factory.subscriptions.SubscriptionChargeWebhookService;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The one place a verified Freedom Pay webhook delivery turns into a
 * {@code Payment}/{@code Booking} state transition — see {@code
 * PaymentWebhookController} for the HTTP/XML edge and ADR-0006's Webhook
 * Architecture for the full race-condition catalogue (cases A-F) this
 * class's ordering (dedupe -> resolve -> verify -> transition) is built to
 * survive.
 */
@Service
class PaymentWebhookProcessor {

    private static final Logger log = LoggerFactory.getLogger(PaymentWebhookProcessor.class);

    private final PaymentWebhookEventRepository webhookEventRepository;
    private final PaymentWebhookEventRecorder eventRecorder;
    private final PaymentRepository paymentRepository;
    private final PaymentRefundRequestRepository refundRequestRepository;
    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final SubscriptionChargeWebhookService subscriptionChargeWebhookService;
    private final PaymentAllocationService paymentAllocationService;
    private final ApplicationEventPublisher eventPublisher;
    private final SavedCardService savedCardService;

    PaymentWebhookProcessor(PaymentWebhookEventRepository webhookEventRepository,
            PaymentWebhookEventRecorder eventRecorder, PaymentRepository paymentRepository,
            PaymentRefundRequestRepository refundRequestRepository, BookingRepository bookingRepository,
            BookingService bookingService, SubscriptionChargeWebhookService subscriptionChargeWebhookService,
            PaymentAllocationService paymentAllocationService, ApplicationEventPublisher eventPublisher,
            SavedCardService savedCardService) {
        this.webhookEventRepository = webhookEventRepository;
        this.eventRecorder = eventRecorder;
        this.paymentRepository = paymentRepository;
        this.refundRequestRepository = refundRequestRepository;
        this.bookingRepository = bookingRepository;
        this.bookingService = bookingService;
        this.subscriptionChargeWebhookService = subscriptionChargeWebhookService;
        this.paymentAllocationService = paymentAllocationService;
        this.eventPublisher = eventPublisher;
        this.savedCardService = savedCardService;
    }

    enum Outcome {
        /** Applied a real state transition (or confirmed one was already correctly applied). */
        ACCEPTED,
        /** Same {@code (provider, eventId)} already recorded — a safe no-op (race C: duplicate webhook). */
        DUPLICATE,
        /** Understood the delivery but there's nothing valid to act on (bad signature, unknown payment, amount mismatch). */
        REJECTED
    }

    record Result(Outcome outcome, String message) {
    }

    /**
     * {@code payloadHash} is audit-only (see {@code PaymentWebhookEvent}'s
     * doc comment) — dedup itself is the {@code (provider, eventId)} unique
     * constraint below, not a hash comparison.
     */
    @Transactional
    Result process(VerifiedWebhook webhook, String payloadHash) {
        if (!webhook.signatureValid()) {
            log.warn("Freedom Pay webhook rejected: invalid signature ({})", webhook.invalidReason());
            return new Result(Outcome.REJECTED, "invalid signature: " + webhook.invalidReason());
        }

        PaymentWebhookEvent event;
        try {
            event = eventRecorder.record(PaymentProviderName.FREEDOMPAY, webhook.providerPaymentId(), payloadHash);
        } catch (DataIntegrityViolationException e) {
            // Same pg_payment_id already recorded — Freedom Pay retries the
            // same Result-notify delivery up to 4x/2h (no per-delivery id
            // of its own, see FreedomPayWebhookVerifier's doc comment).
            // Acking without reprocessing is what makes that safe.
            log.info("Freedom Pay webhook duplicate: providerPaymentId={}", webhook.providerPaymentId());
            return new Result(Outcome.DUPLICATE, "already processed");
        }

        Optional<UUID> paymentId = FreedomPayOrderIds.parseBookingPaymentId(webhook.orderId());
        if (paymentId.isPresent()) {
            return processBookingPayment(event, paymentId.get(), webhook);
        }

        Optional<UUID> chargeId = FreedomPayOrderIds.parseSubscriptionChargeId(webhook.orderId());
        if (chargeId.isPresent()) {
            return processSubscriptionCharge(event, chargeId.get(), webhook);
        }

        event.markFailed("unrecognized pg_order_id=" + webhook.orderId(), Instant.now());
        webhookEventRepository.save(event);
        log.warn("Freedom Pay webhook rejected: unresolved order id {}", webhook.orderId());
        return new Result(Outcome.REJECTED, "unknown payment");
    }

    private Result processBookingPayment(PaymentWebhookEvent event, UUID paymentId, VerifiedWebhook webhook) {
        Optional<Payment> maybePayment = paymentRepository.findById(paymentId);
        if (maybePayment.isEmpty()) {
            event.markFailed("no matching payment for pg_order_id=" + webhook.orderId(), Instant.now());
            webhookEventRepository.save(event);
            log.warn("Freedom Pay webhook rejected: unresolved order id {}", webhook.orderId());
            return new Result(Outcome.REJECTED, "unknown payment");
        }

        Payment payment = maybePayment.get();
        event.assignPayment(payment.getId());

        if (!amountAndCurrencyMatch(payment, webhook)) {
            event.markFailed("amount/currency mismatch", Instant.now());
            webhookEventRepository.save(event);
            log.warn("Freedom Pay webhook rejected: amount/currency mismatch for payment {}", payment.getId());
            return new Result(Outcome.REJECTED, "amount/currency mismatch");
        }

        applyTransition(payment, webhook);
        event.markProcessed(Instant.now());
        webhookEventRepository.save(event);
        return new Result(Outcome.ACCEPTED, "processed");
    }

    /**
     * The subscription-charge counterpart of {@link #processBookingPayment}
     * -- delegates the actual charge/subscription state transition to
     * {@code subscriptions.SubscriptionChargeWebhookService} (see that
     * class's own doc comment for why this stays a delegation rather than a
     * second copy of Payment's own transition logic), and only translates
     * its outcome back into this class's webhook-event bookkeeping/{@link
     * Result}.
     */
    private Result processSubscriptionCharge(PaymentWebhookEvent event, UUID chargeId, VerifiedWebhook webhook) {
        event.assignPayment(chargeId);
        String failureReason = webhook.paymentSucceeded() ? null : "Freedom Pay reported failure (pg_result != 1)";
        SubscriptionChargeWebhookService.Outcome outcome = subscriptionChargeWebhookService.applyChargeResult(
                chargeId, webhook.paymentSucceeded(), webhook.providerPaymentId(), webhook.amount(),
                webhook.currency(), failureReason, new SubscriptionChargeWebhookService.CardOnFile(
                        webhook.recurringProfileId(), webhook.cardPan(), webhook.cardBrand()));
        return switch (outcome) {
            case APPLIED -> {
                event.markProcessed(Instant.now());
                webhookEventRepository.save(event);
                yield new Result(Outcome.ACCEPTED, "processed");
            }
            case ALREADY_RESOLVED -> {
                event.markProcessed(Instant.now());
                webhookEventRepository.save(event);
                log.info("Freedom Pay webhook no-op: subscription charge {} already resolved", chargeId);
                yield new Result(Outcome.ACCEPTED, "already resolved");
            }
            case UNKNOWN_CHARGE -> {
                event.markFailed("no matching subscription charge for pg_order_id=" + webhook.orderId(),
                        Instant.now());
                webhookEventRepository.save(event);
                log.warn("Freedom Pay webhook rejected: unresolved order id {}", webhook.orderId());
                yield new Result(Outcome.REJECTED, "unknown payment");
            }
            case AMOUNT_MISMATCH -> {
                event.markFailed("amount/currency mismatch", Instant.now());
                webhookEventRepository.save(event);
                log.warn("Freedom Pay webhook rejected: amount/currency mismatch for subscription charge {}",
                        chargeId);
                yield new Result(Outcome.REJECTED, "amount/currency mismatch");
            }
        };
    }

    /**
     * Payment/Booking transitions live in the <b>same</b> transaction as
     * the webhook-event write — deliberately not decoupled via the
     * ADR-0002 event pattern this codebase uses everywhere else, because
     * decoupling this one transition is exactly the class of bug ADR-0006
     * was written to close (a confirmed payment whose booking confirmation
     * is only "eventually" applied).
     */
    private void applyTransition(Payment payment, VerifiedWebhook webhook) {
        Instant now = Instant.now();

        // Already resolved (race A already ran, or race D/B raced this
        // delivery and won) — safe no-op, not a conflict.
        if (payment.getStatus() != PaymentStatus.CREATED && payment.getStatus() != PaymentStatus.PENDING) {
            log.info("Freedom Pay webhook no-op: payment {} already {}", payment.getId(), payment.getStatus());
            return;
        }

        if (!webhook.paymentSucceeded()) {
            payment.markFailed("Freedom Pay reported failure (pg_result != 1)", now);
            paymentRepository.save(payment);
            return;
        }

        payment.markSucceeded(webhook.providerPaymentId(), now);
        paymentRepository.save(payment);
        paymentAllocationService.ensureAllocation(payment);

        Booking booking = bookingRepository.findById(payment.getBookingId())
                .orElseThrow(() -> new IllegalStateException("Payment " + payment.getId() + " has no booking "
                        + payment.getBookingId()));

        if (payment.isSaveCard()) {
            savedCardService.save(booking.getUserId(), webhook.recurringProfileId(), webhook.cardPan(),
                    webhook.cardBrand());
        }

        if (booking.getStatus() == BookingStatus.PENDING_PAYMENT) {
            bookingService.confirmAfterPayment(booking.getId());
            return;
        }

        if (booking.getStatus() == BookingStatus.CANCELLED) {
            // Race F: the sweep job (or an explicit cancel) already gave up
            // on this booking — possibly reassigning its slot — before this
            // late webhook confirmed the charge. There's nothing left to
            // confirm the customer into, so the money goes back rather than
            // silently being kept for a booking that no longer exists.
            // Durable refund request, same mechanism (and same doc comment)
            // as BookingCancelledPaymentListener — this transaction is
            // already open, so the row commits atomically with the
            // markSucceeded write above.
            log.warn("Freedom Pay webhook: payment {} succeeded for already-cancelled booking {} — "
                    + "queuing refund", payment.getId(), booking.getId());
            PaymentRefundRequest request = refundRequestRepository.save(new PaymentRefundRequest(UUID.randomUUID(),
                    payment.getId(), payment.getBookingId(), payment.getAmount(), payment.getCurrency(),
                    payment.getProvider(), payment.getProviderReference(), now));
            payment.markRefundPending(now);
            paymentRepository.save(payment);
            eventPublisher.publishEvent(new PaymentRefundRequestReady(request.getId()));
        }
        // Any other booking status (already CONFIRMED/COMPLETED/NO_SHOW) is
        // a safe no-op — the payment is now durably SUCCEEDED either way.
    }

    private static boolean amountAndCurrencyMatch(Payment payment, VerifiedWebhook webhook) {
        if (webhook.amount() != null && webhook.amount().compareTo(payment.getAmount()) != 0) {
            return false;
        }
        return webhook.currency() == null || webhook.currency().equalsIgnoreCase(payment.getCurrency());
    }
}
