package com.zairo.factory.loyalty;

import com.zairo.factory.booking.BookingCompletedEvent;
import com.zairo.factory.reviews.ReviewCreatedEvent;
import java.time.Clock;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Turns real booking/review activity into a durable {@link
 * LoyaltyOutboxEvent} row -- see this module's own package-info
 * ("Computed on events, same pattern as Customer Intelligence") and {@link
 * LoyaltyOutboxEvent}'s own doc comment for the full "why".
 *
 * <p>Deliberately a plain {@link EventListener}, not {@code
 * @TransactionalEventListener(AFTER_COMMIT)}: it must run <em>inside</em>
 * the same transaction as the booking-completion/review-creation write
 * (ADR-0002's synchronous in-process publish means that transaction is
 * still open here), so the outbox row commits atomically with the fact it
 * records. Earlier this class did the earning computation itself,
 * AFTER_COMMIT and best-effort -- any failure (or a crash between commit
 * and the listener firing) silently lost that booking's points forever,
 * with no retry. Now this class only ever does one cheap, unlikely-to-fail
 * insert; the actual computation lives in {@link LoyaltyEarningProcessor},
 * run durably and retried by {@link LoyaltyOutboxProcessor}.
 *
 * <p>A disabled or never-configured program still gets an outbox row (the
 * cheap check happens later, in the processor) -- existing businesses that
 * haven't touched Loyalty pay one extra small row per booking/review, not
 * a behavior change.
 */
@Component
class LoyaltyEarningListener {

    private final LoyaltyOutboxEventRepository outboxRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    LoyaltyEarningListener(LoyaltyOutboxEventRepository outboxRepository, ApplicationEventPublisher eventPublisher,
            Clock clock) {
        this.outboxRepository = outboxRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    @EventListener
    @Transactional
    void onBookingCompleted(BookingCompletedEvent event) {
        LoyaltyOutboxEvent outboxEvent = outboxRepository.save(new LoyaltyOutboxEvent(UUID.randomUUID(),
                LoyaltyOutboxEventType.BOOKING_COMPLETED, event.providerId(), event.userId(), event.bookingId(),
                null, clock.instant()));
        // Best-effort nudge for near-immediate processing (see
        // LoyaltyOutboxEventReady's own doc comment) -- the row saved above
        // is what actually guarantees this is never lost.
        eventPublisher.publishEvent(new LoyaltyOutboxEventReady(outboxEvent.getId()));
    }

    @EventListener
    @Transactional
    void onReviewCreated(ReviewCreatedEvent event) {
        LoyaltyOutboxEvent outboxEvent = outboxRepository.save(new LoyaltyOutboxEvent(UUID.randomUUID(),
                LoyaltyOutboxEventType.REVIEW_CREATED, event.providerId(), event.userId(), event.bookingId(),
                event.reviewId(), clock.instant()));
        eventPublisher.publishEvent(new LoyaltyOutboxEventReady(outboxEvent.getId()));
    }
}
