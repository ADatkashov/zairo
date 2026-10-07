package com.zairo.factory.loyalty;

import java.time.Clock;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * The per-item half of {@link LoyaltyOutboxProcessor}'s sweep, split into
 * its own bean specifically so {@link #attemptProcessing}/{@link
 * #recordFailure}'s {@code @Transactional} annotations actually take
 * effect -- same reasoning {@code payments.PaymentWebhookEventRecorder} is
 * its own bean rather than a private method: Spring's proxy-based AOP only
 * intercepts calls that arrive <em>through</em> the proxy, so a method
 * calling {@code this.otherMethod()} inside the same class silently skips
 * {@code @Transactional} (and, critically, {@code REQUIRES_NEW}) entirely.
 * {@link LoyaltyOutboxProcessor} calls into this class's methods as a
 * genuinely separate injected bean, so both annotations apply as written.
 */
@Component
class LoyaltyOutboxItemProcessor {

    private static final Logger log = LoggerFactory.getLogger(LoyaltyOutboxItemProcessor.class);

    private final LoyaltyOutboxEventRepository outboxRepository;
    private final LoyaltyEarningProcessor earningProcessor;
    private final Clock clock;

    LoyaltyOutboxItemProcessor(LoyaltyOutboxEventRepository outboxRepository, LoyaltyEarningProcessor earningProcessor,
            Clock clock) {
        this.outboxRepository = outboxRepository;
        this.earningProcessor = earningProcessor;
        this.clock = clock;
    }

    /**
     * One transaction covering the read, the actual earning computation, and marking the row PROCESSED. Always a
     * genuinely new transaction: the nudge that triggers this runs AFTER_COMMIT of the booking transaction, whose
     * (already committed) resources are still bound to the thread — joining them fails with "No active
     * transaction for update or delete query".
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    boolean attemptProcessing(UUID eventId) {
        LoyaltyOutboxEvent event = outboxRepository.findById(eventId).orElse(null);
        if (event == null || event.getStatus() != LoyaltyOutboxEventStatus.PENDING) {
            return true; // already handled by a previous pass, or gone -- nothing left to do
        }
        switch (event.getEventType()) {
            case BOOKING_COMPLETED ->
                earningProcessor.processBookingCompleted(event.getProviderId(), event.getUserId(),
                        event.getBookingId());
            case REVIEW_CREATED ->
                earningProcessor.processReviewCreated(event.getProviderId(), event.getUserId(), event.getBookingId(),
                        event.getReviewId());
            case PAYMENT_REFUNDED ->
                earningProcessor.processPaymentRefunded(event.getProviderId(), event.getUserId(),
                        event.getBookingId());
        }
        event.markProcessed(clock.instant());
        outboxRepository.save(event);
        return true;
    }

    /** Isolated (genuinely, via REQUIRES_NEW) from the failed attempt's own rolled-back transaction. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    boolean recordFailure(UUID eventId, String error) {
        LoyaltyOutboxEvent event = outboxRepository.findById(eventId).orElse(null);
        if (event == null || event.getStatus() != LoyaltyOutboxEventStatus.PENDING) {
            return true;
        }
        event.recordFailure(error);
        boolean deadLettered = event.getAttempts() >= LoyaltyOutboxProcessor.MAX_ATTEMPTS;
        if (deadLettered) {
            event.markFailedPermanently();
            log.error("Loyalty outbox event {} permanently failed after {} attempts, last error: {}", eventId,
                    event.getAttempts(), error);
        }
        outboxRepository.save(event);
        return deadLettered;
    }
}
