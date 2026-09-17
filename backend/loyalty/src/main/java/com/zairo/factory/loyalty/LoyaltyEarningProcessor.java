package com.zairo.factory.loyalty;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * The actual earning-rule computation -- awarding fixed/per-spend booking
 * points, first-booking/repeat-visit bonuses, milestones, and the review
 * bonus. Extracted out of {@link LoyaltyEarningListener} so it can be
 * invoked from {@link LoyaltyOutboxProcessor}'s durable, retryable sweep
 * instead of directly from an in-memory event -- see this module's own
 * package-info and {@link LoyaltyOutboxEvent}'s doc comment for the "why".
 * Every award still goes through {@link LoyaltyLedgerService#earn}, which
 * is itself idempotent per {@code (referenceType, referenceId)} -- running
 * this twice for the same booking/review is always a safe no-op.
 */
@Component
class LoyaltyEarningProcessor {

    private final LoyaltyProgramRepository programRepository;
    private final LoyaltyLedgerService ledgerService;
    private final LoyaltyMilestoneRuleRepository milestoneRuleRepository;
    private final BookingRepository bookingRepository;

    LoyaltyEarningProcessor(LoyaltyProgramRepository programRepository, LoyaltyLedgerService ledgerService,
            LoyaltyMilestoneRuleRepository milestoneRuleRepository, BookingRepository bookingRepository) {
        this.programRepository = programRepository;
        this.ledgerService = ledgerService;
        this.milestoneRuleRepository = milestoneRuleRepository;
        this.bookingRepository = bookingRepository;
    }

    @Transactional
    void processBookingCompleted(UUID providerId, UUID userId, UUID bookingId) {
        LoyaltyProgram program = programRepository.findByProviderId(providerId).orElse(null);
        if (program == null || !program.isEnabled()) {
            return;
        }

        Booking booking = bookingRepository.findById(bookingId).orElse(null);
        if (booking == null) {
            return;
        }

        int bookingPoints = computeBookingPoints(program, booking);
        if (bookingPoints > 0) {
            ledgerService.earn(providerId, userId, bookingPoints, LoyaltyTransactionType.EARNED,
                    LoyaltyReferenceType.BOOKING_EARNING, bookingId, bookingId, "Booking completed", program);
        }

        List<Booking> completedVisits = bookingRepository.findCompletedByUserIdAndProviderIdOrderByVisitDate(userId,
                providerId);
        int visitNumber = completedVisits.size();
        ledgerService.syncCompletedVisits(providerId, userId, visitNumber);

        if (visitNumber == 1 && program.getFirstBookingBonusPoints() > 0) {
            ledgerService.earn(providerId, userId, program.getFirstBookingBonusPoints(), LoyaltyTransactionType.BONUS,
                    LoyaltyReferenceType.FIRST_BOOKING_BONUS, bookingId, bookingId, "First booking bonus", program);
        }

        if (visitNumber == program.getRepeatVisitThreshold() && program.getRepeatVisitBonusPoints() > 0) {
            ledgerService.earn(providerId, userId, program.getRepeatVisitBonusPoints(), LoyaltyTransactionType.BONUS,
                    LoyaltyReferenceType.REPEAT_VISIT_BONUS, bookingId, bookingId, "Repeat visit bonus", program);
        }

        for (LoyaltyMilestoneRule milestone : milestoneRuleRepository
                .findByProgramIdOrderByVisitsRequiredAsc(program.getId())) {
            if (milestone.getVisitsRequired() <= visitNumber) {
                ledgerService.earn(providerId, userId, milestone.getPointsAwarded(), LoyaltyTransactionType.BONUS,
                        LoyaltyReferenceType.MILESTONE, milestone.getId(), bookingId,
                        "Milestone reached: " + milestoneLabel(milestone), program);
            }
        }
    }

    @Transactional
    void processReviewCreated(UUID providerId, UUID userId, UUID bookingId, UUID reviewId) {
        LoyaltyProgram program = programRepository.findByProviderId(providerId).orElse(null);
        if (program == null || !program.isEnabled() || program.getReviewBonusPoints() <= 0) {
            return;
        }
        ledgerService.earn(providerId, userId, program.getReviewBonusPoints(), LoyaltyTransactionType.BONUS,
                LoyaltyReferenceType.REVIEW_BONUS, bookingId, bookingId, "Review bonus", program);
    }

    /**
     * Claws back a COMPLETED booking's own BOOKING_EARNING points after its
     * payment was refunded post-completion -- see {@link
     * LoyaltyRefundListener}. Only the direct booking-completion award is
     * reversed, not first-booking/repeat-visit/milestone bonuses tied to
     * overall visit cadence rather than this one booking's value; if the
     * booking never earned anything (program disabled/never configured at
     * the time), this is a no-op.
     */
    @Transactional
    void processPaymentRefunded(UUID providerId, UUID userId, UUID bookingId) {
        LoyaltyTransaction original = ledgerService.findEarningTransaction(providerId, userId,
                LoyaltyReferenceType.BOOKING_EARNING, bookingId);
        if (original == null) {
            return;
        }
        ledgerService.reverseEarning(providerId, userId, original.getPointsDelta(),
                "Booking payment refunded after completion", LoyaltyReferenceType.PAYMENT_REFUND_REVERSAL, bookingId,
                bookingId);
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
