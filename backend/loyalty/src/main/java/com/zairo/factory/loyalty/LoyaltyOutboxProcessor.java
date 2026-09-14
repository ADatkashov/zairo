package com.zairo.factory.loyalty;

import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * The durable, retrying half of loyalty earning (Phase 0 stabilization) --
 * see {@link LoyaltyOutboxEvent} and {@link LoyaltyEarningListener}'s own
 * doc comments for the full design. Polls PENDING {@link LoyaltyOutboxEvent}
 * rows and runs {@link LoyaltyEarningProcessor} (via {@link
 * LoyaltyOutboxItemProcessor}) against each one, oldest first, in bounded
 * pages -- same re-query-each-pass shape as {@code LoyaltyExpirationJob}'s
 * sweep, for the same reason (a row that finishes processing drops out of
 * the PENDING predicate, so page 0 always reflects what's still actually
 * due).
 *
 * <p>Two triggers, one code path: {@link #onOutboxEventReady} fires the
 * eager, common-case attempt right after the row's own transaction
 * commits (near-instant, matching what earning felt like before this
 * table existed), while {@link #run} sweeps every 15s (not once a day like
 * expiration -- a customer expects their points to show up shortly after
 * their visit) as the durability backstop for whatever the eager attempt
 * missed: a crash before it could fire, a transient failure, or a restart
 * mid-processing.
 *
 * <p>The actual per-item transactions live in {@link
 * LoyaltyOutboxItemProcessor}, a separate bean -- necessary (not just
 * tidiness) because calling {@code @Transactional}/{@code REQUIRES_NEW}
 * methods on {@code this} from inside the same class silently bypasses
 * Spring's proxy-based AOP; see that class's own doc comment.
 */
@Component
class LoyaltyOutboxProcessor {

    private static final Logger log = LoggerFactory.getLogger(LoyaltyOutboxProcessor.class);
    private static final int PAGE_SIZE = 200;
    static final int MAX_ATTEMPTS = 10;

    private final LoyaltyOutboxEventRepository outboxRepository;
    private final LoyaltyOutboxItemProcessor itemProcessor;

    LoyaltyOutboxProcessor(LoyaltyOutboxEventRepository outboxRepository, LoyaltyOutboxItemProcessor itemProcessor) {
        this.outboxRepository = outboxRepository;
        this.itemProcessor = itemProcessor;
    }

    /**
     * The eager, near-immediate fast path -- see {@link
     * LoyaltyOutboxEventReady}'s own doc comment. Fires right after the
     * booking/review/refund transaction that created the row commits.
     * Failure here is silently absorbed by {@link #processOne}: the row
     * simply stays PENDING and {@link #run}'s next sweep retries it, so
     * this is purely a latency optimization, never a second place
     * durability depends on.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onOutboxEventReady(LoyaltyOutboxEventReady ready) {
        processOne(ready.outboxEventId());
    }

    @Scheduled(fixedDelay = 15_000)
    void run() {
        List<LoyaltyOutboxEvent> page;
        boolean progressed;
        do {
            page = outboxRepository.findByStatusOrderByCreatedAtAsc(LoyaltyOutboxEventStatus.PENDING,
                    PageRequest.of(0, PAGE_SIZE));
            progressed = false;
            for (LoyaltyOutboxEvent event : page) {
                progressed |= processOne(event.getId());
            }
        } while (!page.isEmpty() && progressed);
    }

    /** Returns true if the row left PENDING status (processed or dead-lettered) -- false if it's still PENDING to retry. */
    private boolean processOne(UUID eventId) {
        try {
            return itemProcessor.attemptProcessing(eventId);
        } catch (RuntimeException e) {
            log.error("Failed to process loyalty outbox event {}: {}", eventId, e.getMessage(), e);
            return itemProcessor.recordFailure(eventId, e.getMessage());
        }
    }
}
