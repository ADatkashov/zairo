package com.zairo.factory.loyalty;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Redeem-a-reward-for-points and apply-a-redemption-to-a-booking -- see
 * this module's own package-info for why "apply" stops at recording the
 * redemption against a booking rather than rewriting {@code
 * booking.Booking}'s own stored price.
 */
@Service
public class LoyaltyRedemptionService {

    /** No ambiguous-looking characters (0/O, 1/I/L) -- a code a customer might read aloud or retype at checkout. */
    private static final String CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static final int CODE_LENGTH = 8;
    private static final int DEFAULT_REDEMPTION_VALIDITY_DAYS = 90;

    private final LoyaltyRedemptionRepository redemptionRepository;
    private final LoyaltyRewardRepository rewardRepository;
    private final LoyaltyProgramRepository programRepository;
    private final LoyaltyLedgerService ledgerService;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public LoyaltyRedemptionService(LoyaltyRedemptionRepository redemptionRepository,
            LoyaltyRewardRepository rewardRepository, LoyaltyProgramRepository programRepository,
            LoyaltyLedgerService ledgerService, BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, Clock clock) {
        this.redemptionRepository = redemptionRepository;
        this.rewardRepository = rewardRepository;
        this.programRepository = programRepository;
        this.ledgerService = ledgerService;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.clock = clock;
    }

    /**
     * Spends points on a reward: validates the program is enabled, the
     * reward is currently redeemable, and the account can afford it, then
     * deducts the points and issues a redemption code -- all inside one
     * transaction via {@link LoyaltyLedgerService#consume}'s own account
     * lock, so two concurrent redemption requests against a
     * nearly-exhausted balance can't both succeed (Phase 19).
     */
    @Transactional
    public LoyaltyRedemption redeem(UUID userId, UUID rewardId) {
        LoyaltyReward reward = rewardRepository.findById(rewardId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Reward not found: " + rewardId));
        UUID providerId = reward.getProviderId();

        LoyaltyProgram program = programRepository.findByProviderId(providerId)
                .filter(LoyaltyProgram::isEnabled)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT,
                        "Loyalty is not enabled for this business"));

        Instant now = clock.instant();
        if (!reward.isRedeemableAt(now)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This reward is not currently available");
        }

        LoyaltyAccount account = ledgerService.getOrCreateAccountForUpdate(providerId, userId);
        if (program.getMinRedemptionPoints() != null && account.getPointsBalance() < program.getMinRedemptionPoints()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "A minimum balance of "
                    + program.getMinRedemptionPoints() + " points is required to redeem any reward");
        }
        if (account.getPointsBalance() < reward.getPointsCost()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Insufficient points: this reward costs "
                    + reward.getPointsCost() + ", you have " + account.getPointsBalance());
        }

        UUID redemptionId = UUID.randomUUID();
        ledgerService.consume(providerId, userId, reward.getPointsCost(), LoyaltyTransactionType.REDEEMED,
                LoyaltyReferenceType.REWARD_REDEMPTION, redemptionId, null, rewardId, redemptionId, null,
                "Redeemed reward: " + reward.getName());

        reward.incrementRedemptions();
        rewardRepository.save(reward);

        Instant expiresAt = reward.getEndsAt() != null && reward.getEndsAt().isBefore(defaultExpiry(now))
                ? reward.getEndsAt()
                : defaultExpiry(now);
        LoyaltyRedemption redemption = new LoyaltyRedemption(redemptionId, providerId, userId, rewardId,
                reward.getPointsCost(), generateUniqueCode(), reward, now, expiresAt);
        return redemptionRepository.save(redemption);
    }

    /** Self-service: a customer giving up an unused code they redeemed by mistake, before a business ever applies it. */
    @Transactional
    public LoyaltyRedemption cancelAsCustomer(UUID redemptionId, UUID callerId, String reason) {
        LoyaltyRedemption redemption = redemptionRepository.findById(redemptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption not found: "
                        + redemptionId));
        if (!redemption.getUserId().equals(callerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption not found: " + redemptionId);
        }
        return cancel(redemption, reason);
    }

    /** Business-initiated cancellation of one of its own active redemption codes (e.g. suspected abuse). */
    @Transactional
    public LoyaltyRedemption cancelAsBusiness(UUID providerId, UUID redemptionId, String reason) {
        LoyaltyRedemption redemption = redemptionRepository.findById(redemptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption not found: "
                        + redemptionId));
        if (!redemption.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption not found: " + redemptionId);
        }
        return cancel(redemption, reason);
    }

    private LoyaltyRedemption cancel(LoyaltyRedemption redemption, String reason) {
        // Re-fetch under a pessimistic lock before transitioning status --
        // the initial lookups above (by id, scoped to the caller) are
        // plain reads; two concurrent cancel calls for the same redemption
        // must not both observe ACTIVE and both refund the same points.
        UUID redemptionId = redemption.getId();
        redemption = redemptionRepository.lockById(redemptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption not found: "
                        + redemptionId));
        if (redemption.getStatus() != LoyaltyRedemptionStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only an active, unused redemption can be "
                    + "cancelled (current status: " + redemption.getStatus() + ")");
        }
        Instant now = clock.instant();
        LoyaltyProgram program = programRepository.findByProviderId(redemption.getProviderId()).orElse(null);
        ledgerService.refund(redemption.getProviderId(), redemption.getUserId(), redemption.getPointsSpent(),
                "Redemption cancelled: " + (reason == null || reason.isBlank() ? "no reason given" : reason),
                redemption.getId(), program);

        rewardRepository.findById(redemption.getRewardId()).ifPresent(reward -> {
            reward.decrementRedemptions();
            rewardRepository.save(reward);
        });

        redemption.markCancelled(reason, now);
        return redemptionRepository.save(redemption);
    }

    /**
     * The business's checkout-time confirmation step (Phase 7): looks a
     * customer's redemption code up and ties it to a specific booking of
     * theirs, at this same business. Deliberately does not touch {@code
     * booking.Booking}'s stored price -- see this module's own
     * package-info for why a deeper checkout-pricing integration is a
     * follow-up, not part of this iteration. What it does guarantee: the
     * discount a customer actually gets is always read from the reward's
     * own server-held snapshot, never a client-supplied amount.
     */
    @Transactional
    public LoyaltyRedemption applyToBooking(UUID providerId, String code, UUID bookingId) {
        // Locked from the first read: two concurrent apply calls for the
        // same code must serialize rather than both observe ACTIVE and
        // both transition it (Phase 0 stabilization) -- same guarantee
        // LoyaltyLedgerService#consume gives the account row.
        LoyaltyRedemption redemption = redemptionRepository.lockByCode(code)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption code not found"));
        if (!redemption.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption code not found");
        }

        Instant now = clock.instant();
        if (redemption.getStatus() == LoyaltyRedemptionStatus.ACTIVE && redemption.getExpiresAt() != null
                && now.isAfter(redemption.getExpiresAt())) {
            redemption.markExpired();
            redemptionRepository.save(redemption);
        }
        if (redemption.getStatus() != LoyaltyRedemptionStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This redemption code is " + redemption.getStatus()
                    + " and cannot be applied");
        }

        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: " + bookingId));
        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found"));
        if (!slot.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Booking does not belong to this business");
        }
        if (!booking.getUserId().equals(redemption.getUserId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Booking belongs to a different customer than this redemption");
        }

        LoyaltyProgram program = programRepository.findByProviderId(providerId).orElse(null);
        if (program != null && program.getMaxRedemptionPointsPerBooking() != null) {
            int alreadyApplied = redemptionRepository
                    .findByAppliedBookingIdAndStatus(bookingId, LoyaltyRedemptionStatus.APPLIED).stream()
                    .mapToInt(LoyaltyRedemption::getPointsSpent).sum();
            if (alreadyApplied + redemption.getPointsSpent() > program.getMaxRedemptionPointsPerBooking()) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Applying this redemption would exceed the "
                        + "maximum of " + program.getMaxRedemptionPointsPerBooking() + " points per booking");
            }
        }

        redemption.markApplied(bookingId, now);
        return redemptionRepository.save(redemption);
    }

    public Page<LoyaltyRedemption> findByCustomer(UUID userId, Pageable pageable) {
        return redemptionRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
    }

    public Page<LoyaltyRedemption> findByBusiness(UUID providerId, Pageable pageable) {
        return redemptionRepository.findByProviderIdOrderByCreatedAtDesc(providerId, pageable);
    }

    public LoyaltyRedemption getOwnedByCustomer(UUID redemptionId, UUID callerId) {
        LoyaltyRedemption redemption = redemptionRepository.findById(redemptionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption not found: "
                        + redemptionId));
        if (!redemption.getUserId().equals(callerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Redemption not found: " + redemptionId);
        }
        return redemption;
    }

    /** Lazily expires ACTIVE redemptions whose validity window has passed -- called by LoyaltyExpirationJob's daily sweep. */
    @Transactional
    public int expireDueRedemptions() {
        List<LoyaltyRedemption> due = redemptionRepository
                .findByStatusAndExpiresAtBefore(LoyaltyRedemptionStatus.ACTIVE, clock.instant());
        due.forEach(LoyaltyRedemption::markExpired);
        redemptionRepository.saveAll(due);
        return due.size();
    }

    private Instant defaultExpiry(Instant now) {
        return now.plus(DEFAULT_REDEMPTION_VALIDITY_DAYS, ChronoUnit.DAYS);
    }

    private String generateUniqueCode() {
        for (int attempt = 0; attempt < 20; attempt++) {
            StringBuilder code = new StringBuilder(CODE_LENGTH);
            for (int i = 0; i < CODE_LENGTH; i++) {
                code.append(CODE_ALPHABET.charAt(random.nextInt(CODE_ALPHABET.length())));
            }
            if (!redemptionRepository.existsByCode(code.toString())) {
                return code.toString();
            }
        }
        throw new IllegalStateException("Could not generate a unique redemption code after 20 attempts");
    }
}
