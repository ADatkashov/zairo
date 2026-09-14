package com.zairo.factory.loyalty;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingCompletedEvent;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.reviews.ReviewCreatedEvent;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Turns real booking/review activity into points -- see this module's own
 * package-info ("Computed on events, same pattern as Customer
 * Intelligence"). Every award goes through {@link LoyaltyLedgerService#earn},
 * which is itself idempotent per {@code (referenceType, referenceId)} -- a
 * duplicated event never double-awards (Phase 19).
 *
 * <p>A disabled or never-configured program means every method here is a
 * silent no-op -- existing businesses that haven't touched Loyalty behave
 * exactly as before this module existed (Phase 29).
 */
@Component
class LoyaltyEarningListener {

    private static final Logger log = LoggerFactory.getLogger(LoyaltyEarningListener.class);

    private final LoyaltyProgramRepository programRepository;
    private final LoyaltyLedgerService ledgerService;
    private final LoyaltyMilestoneRuleRepository milestoneRuleRepository;
    private final BookingRepository bookingRepository;

    LoyaltyEarningListener(LoyaltyProgramRepository programRepository, LoyaltyLedgerService ledgerService,
            LoyaltyMilestoneRuleRepository milestoneRuleRepository, BookingRepository bookingRepository) {
        this.programRepository = programRepository;
        this.ledgerService = ledgerService;
        this.milestoneRuleRepository = milestoneRuleRepository;
        this.bookingRepository = bookingRepository;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onBookingCompleted(BookingCompletedEvent event) {
        try {
            handleBookingCompleted(event);
        } catch (RuntimeException e) {
            // A booking's own completion must never fail because loyalty
            // couldn't award points -- same "log and move on" discipline
            // BookingPaymentTimeoutJob uses for a per-item failure in a
            // batch, just for a single event here.
            log.error("Failed to process loyalty earning for booking {}: {}", event.bookingId(), e.getMessage(), e);
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onReviewCreated(ReviewCreatedEvent event) {
        try {
            handleReviewCreated(event);
        } catch (RuntimeException e) {
            log.error("Failed to process loyalty review bonus for review {}: {}", event.reviewId(), e.getMessage(),
                    e);
        }
    }

    private void handleBookingCompleted(BookingCompletedEvent event) {
        LoyaltyProgram program = programRepository.findByProviderId(event.providerId()).orElse(null);
        if (program == null || !program.isEnabled()) {
            return;
        }

        Booking booking = bookingRepository.findById(event.bookingId()).orElse(null);
        if (booking == null) {
            return;
        }

        int bookingPoints = computeBookingPoints(program, booking);
        if (bookingPoints > 0) {
            ledgerService.earn(event.providerId(), event.userId(), bookingPoints, LoyaltyTransactionType.EARNED,
                    LoyaltyReferenceType.BOOKING_EARNING, event.bookingId(), event.bookingId(), "Booking completed",
                    program);
        }

        List<Booking> completedVisits = bookingRepository
                .findCompletedByUserIdAndProviderIdOrderByVisitDate(event.userId(), event.providerId());
        int visitNumber = completedVisits.size();
        ledgerService.syncCompletedVisits(event.providerId(), event.userId(), visitNumber);

        if (visitNumber == 1 && program.getFirstBookingBonusPoints() > 0) {
            ledgerService.earn(event.providerId(), event.userId(), program.getFirstBookingBonusPoints(),
                    LoyaltyTransactionType.BONUS, LoyaltyReferenceType.FIRST_BOOKING_BONUS, event.bookingId(),
                    event.bookingId(), "First booking bonus", program);
        }

        if (visitNumber == program.getRepeatVisitThreshold() && program.getRepeatVisitBonusPoints() > 0) {
            ledgerService.earn(event.providerId(), event.userId(), program.getRepeatVisitBonusPoints(),
                    LoyaltyTransactionType.BONUS, LoyaltyReferenceType.REPEAT_VISIT_BONUS, event.bookingId(),
                    event.bookingId(), "Repeat visit bonus", program);
        }

        for (LoyaltyMilestoneRule milestone : milestoneRuleRepository
                .findByProgramIdOrderByVisitsRequiredAsc(program.getId())) {
            if (milestone.getVisitsRequired() <= visitNumber) {
                ledgerService.earn(event.providerId(), event.userId(), milestone.getPointsAwarded(),
                        LoyaltyTransactionType.BONUS, LoyaltyReferenceType.MILESTONE, milestone.getId(),
                        event.bookingId(), "Milestone reached: " + milestoneLabel(milestone), program);
            }
        }
    }

    private void handleReviewCreated(ReviewCreatedEvent event) {
        LoyaltyProgram program = programRepository.findByProviderId(event.providerId()).orElse(null);
        if (program == null || !program.isEnabled() || program.getReviewBonusPoints() <= 0) {
            return;
        }
        ledgerService.earn(event.providerId(), event.userId(), program.getReviewBonusPoints(),
                LoyaltyTransactionType.BONUS, LoyaltyReferenceType.REVIEW_BONUS, event.bookingId(), event.bookingId(),
                "Review bonus", program);
    }

    private static String milestoneLabel(LoyaltyMilestoneRule milestone) {
        return milestone.getLabel() != null ? milestone.getLabel() : milestone.getVisitsRequired() + " visits";
    }

    private static int computeBookingPoints(LoyaltyProgram program, Booking booking) {
        int points = program.getFixedPointsPerBooking();
        if (program.getPointsPerCurrencyUnit() != null && program.getPointsPerCurrencyUnit().signum() > 0) {
            BigDecimal earned = booking.getTotalPrice().multiply(program.getPointsPerCurrencyUnit())
                    .setScale(0, RoundingMode.DOWN);
            points += earned.intValueExact();
        }
        return points;
    }
}
