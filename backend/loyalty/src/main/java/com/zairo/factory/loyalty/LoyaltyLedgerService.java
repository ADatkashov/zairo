package com.zairo.factory.loyalty;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * The one place every {@link LoyaltyAccount} balance change goes through --
 * see this module's own package-info for the ledger/lot/lock design this
 * class implements. Every public method here is self-contained and
 * {@code @Transactional}; callers (earning rules, redemption, expiration,
 * admin adjustment) never touch {@link LoyaltyAccount}/{@link
 * LoyaltyEarnLot} directly.
 */
@Service
public class LoyaltyLedgerService {

    private final LoyaltyAccountRepository accountRepository;
    private final LoyaltyEarnLotRepository earnLotRepository;
    private final LoyaltyTransactionRepository transactionRepository;
    private final Clock clock;

    public LoyaltyLedgerService(LoyaltyAccountRepository accountRepository, LoyaltyEarnLotRepository earnLotRepository,
            LoyaltyTransactionRepository transactionRepository, Clock clock) {
        this.accountRepository = accountRepository;
        this.earnLotRepository = earnLotRepository;
        this.transactionRepository = transactionRepository;
        this.clock = clock;
    }

    /** Read-only -- never creates a row, so browsing a business's loyalty page doesn't persist anything by itself. */
    public Optional<LoyaltyAccount> findAccount(UUID providerId, UUID userId) {
        return accountRepository.findByProviderIdAndUserId(providerId, userId);
    }

    /** Read-only lookup of a specific earning row, e.g. so a refund reversal knows how many points to claw back. */
    public LoyaltyTransaction findEarningTransaction(UUID providerId, UUID userId, LoyaltyReferenceType referenceType,
            UUID referenceId) {
        return transactionRepository
                .findFirstByProviderIdAndUserIdAndReferenceTypeAndReferenceId(providerId, userId, referenceType,
                        referenceId)
                .orElse(null);
    }

    /** Read-only: has this exact (type, reference) already been recorded for the account? */
    public boolean hasEarning(UUID providerId, UUID userId, LoyaltyReferenceType referenceType, UUID referenceId) {
        return transactionRepository.existsByProviderIdAndUserIdAndReferenceTypeAndReferenceId(providerId, userId,
                referenceType, referenceId);
    }

    @Transactional
    public LoyaltyAccount getOrCreateAccount(UUID providerId, UUID userId) {
        return accountRepository.findByProviderIdAndUserId(providerId, userId).orElseGet(() -> {
            accountRepository.insertIfAbsent(UUID.randomUUID(), providerId, userId, clock.instant());
            return accountRepository.findByProviderIdAndUserId(providerId, userId)
                    .orElseThrow(() -> new IllegalStateException("Loyalty account missing immediately after insert: "
                            + providerId + "/" + userId));
        });
    }

    /**
     * Awards points for one of the standard earning rules. Idempotent by
     * {@code (referenceType, referenceId)}: a second call for the exact
     * same reference (a retried event, a duplicated webhook) is a safe
     * no-op, returning empty rather than double-awarding -- see this
     * module's package-info. Subject to the program's daily/monthly
     * earning caps; {@code program} may be null (no caps, no expiry) for
     * a caller that already resolved "should this even be awarded" itself.
     */
    @Transactional
    public Optional<LoyaltyTransaction> earn(UUID providerId, UUID userId, int points, LoyaltyTransactionType type,
            LoyaltyReferenceType referenceType, UUID referenceId, UUID bookingId, String reason,
            LoyaltyProgram program) {
        if (points <= 0) {
            return Optional.empty();
        }
        Instant now = clock.instant();
        LoyaltyAccount account = lockAccount(providerId, userId, now);

        if (referenceType != null && referenceId != null && transactionRepository
                .existsByProviderIdAndUserIdAndReferenceTypeAndReferenceId(providerId, userId, referenceType,
                        referenceId)) {
            return Optional.empty();
        }

        int cappedPoints = applyEarningCaps(program, providerId, userId, points, now);
        if (cappedPoints <= 0) {
            return Optional.empty();
        }

        Instant expiresAt = computeExpiry(program, now);
        LoyaltyTransaction tx = creditLocked(account, type, cappedPoints, reason, referenceType, referenceId,
                bookingId, null, null, null, now, expiresAt);
        return Optional.of(tx);
    }

    /**
     * Restores points after a redemption is cancelled/reversed -- a
     * {@link LoyaltyTransactionType#REFUND}, never subject to earning
     * caps (it isn't new earning, it's undoing a spend) and always given
     * a fresh expiry under the program's current policy.
     */
    @Transactional
    public LoyaltyTransaction refund(UUID providerId, UUID userId, int points, String reason, UUID redemptionId,
            LoyaltyProgram program) {
        if (points <= 0) {
            throw new IllegalArgumentException("Refund points must be positive: " + points);
        }
        Instant now = clock.instant();
        LoyaltyAccount account = lockAccount(providerId, userId, now);
        Instant expiresAt = computeExpiry(program, now);
        return creditLocked(account, LoyaltyTransactionType.REFUND, points, reason,
                LoyaltyReferenceType.REDEMPTION_REVERSAL, redemptionId, null, null, redemptionId, null, now,
                expiresAt);
    }

    /**
     * Spends points -- redemption or expiration. Consumes the customer's
     * oldest still-live {@link LoyaltyEarnLot}s first (FIFO), so the
     * points that expire soonest are always the ones spent first. Throws
     * a 409 if the account doesn't have enough available.
     */
    @Transactional
    public LoyaltyTransaction consume(UUID providerId, UUID userId, int points, LoyaltyTransactionType type,
            LoyaltyReferenceType referenceType, UUID referenceId, UUID bookingId, UUID rewardId, UUID redemptionId,
            UUID actorUserId, String reason) {
        if (points <= 0) {
            throw new IllegalArgumentException("Points to consume must be positive: " + points);
        }
        Instant now = clock.instant();
        LoyaltyAccount account = lockAccount(providerId, userId, now);

        if (points > account.getPointsBalance()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Insufficient loyalty points: requested " + points
                    + ", available " + account.getPointsBalance());
        }

        List<LoyaltyEarnLot> lots = earnLotRepository
                .findByProviderIdAndUserIdAndPointsRemainingGreaterThanOrderByEarnedAtAsc(providerId, userId, 0);
        int remaining = points;
        for (LoyaltyEarnLot lot : lots) {
            if (remaining <= 0) {
                break;
            }
            remaining -= lot.consume(remaining);
            earnLotRepository.save(lot);
        }
        if (remaining > 0) {
            // The cached balance and the sum of live lots have drifted -- a bug elsewhere, not a user-facing error.
            throw new IllegalStateException("Loyalty lots for " + providerId + "/" + userId + " could not cover "
                    + points + " points (short by " + remaining + ")");
        }

        account.debit(points, type, now);
        accountRepository.save(account);

        LoyaltyTransaction tx = LoyaltyTransaction.create(providerId, userId, type, -points,
                account.getPointsBalance(), reason, referenceType, referenceId, bookingId, rewardId, redemptionId,
                actorUserId, now, null);
        return transactionRepository.save(tx);
    }

    /**
     * Claws back previously-earned points after their originating booking's
     * payment was refunded post-completion (Phase 0 stabilization) -- see
     * {@code LoyaltyRefundListener}/{@code LoyaltyRefundProcessor}. Capped
     * at the account's current balance rather than throwing if the customer
     * already spent some or all of those points elsewhere: undoing an
     * earlier award must never take a balance negative. Idempotent per
     * {@code (referenceType, referenceId)} exactly like {@link #earn} -- a
     * retried/duplicated outbox row is a safe no-op.
     */
    @Transactional
    public Optional<LoyaltyTransaction> reverseEarning(UUID providerId, UUID userId, int points, String reason,
            LoyaltyReferenceType referenceType, UUID referenceId, UUID bookingId) {
        if (points <= 0) {
            return Optional.empty();
        }
        Instant now = clock.instant();
        LoyaltyAccount account = lockAccount(providerId, userId, now);

        if (referenceType != null && referenceId != null && transactionRepository
                .existsByProviderIdAndUserIdAndReferenceTypeAndReferenceId(providerId, userId, referenceType,
                        referenceId)) {
            return Optional.empty();
        }

        int amount = Math.min(points, account.getPointsBalance());
        if (amount <= 0) {
            return Optional.empty();
        }

        List<LoyaltyEarnLot> lots = earnLotRepository
                .findByProviderIdAndUserIdAndPointsRemainingGreaterThanOrderByEarnedAtAsc(providerId, userId, 0);
        int remaining = amount;
        for (LoyaltyEarnLot lot : lots) {
            if (remaining <= 0) {
                break;
            }
            remaining -= lot.consume(remaining);
            earnLotRepository.save(lot);
        }
        if (remaining > 0) {
            // Same invariant #consume relies on: live lots always sum to
            // the cached balance, so capping `amount` at the balance above
            // should exhaust exactly that many lot points.
            throw new IllegalStateException("Loyalty lots for " + providerId + "/" + userId + " could not cover "
                    + amount + " points of reversal (short by " + remaining + ")");
        }

        account.debit(amount, LoyaltyTransactionType.REVERSAL, now);
        accountRepository.save(account);

        LoyaltyTransaction tx = LoyaltyTransaction.create(providerId, userId, LoyaltyTransactionType.REVERSAL,
                -amount, account.getPointsBalance(), reason, referenceType, referenceId, bookingId, null, null, null,
                now, null);
        return Optional.of(transactionRepository.save(tx));
    }

    /**
     * A manual, authorized business/admin correction -- always carries a
     * reason and the acting user (Phase 20). Positive deltas bypass
     * earning caps (a human override, not an automated rule); negative
     * deltas go through the same balance/FIFO checks as any other spend.
     */
    @Transactional
    public LoyaltyTransaction adjust(UUID providerId, UUID userId, int delta, String reason, UUID actorUserId,
            LoyaltyProgram program) {
        if (delta == 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Adjustment delta must not be zero");
        }
        if (reason == null || reason.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "An adjustment requires a reason");
        }
        if (actorUserId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "An adjustment requires an acting user");
        }
        if (delta > 0) {
            Instant now = clock.instant();
            LoyaltyAccount account = lockAccount(providerId, userId, now);
            Instant expiresAt = computeExpiry(program, now);
            return creditLocked(account, LoyaltyTransactionType.ADJUSTMENT, delta, reason,
                    LoyaltyReferenceType.MANUAL_ADJUSTMENT, null, null, null, null, actorUserId, now, expiresAt);
        }
        return consume(providerId, userId, -delta, LoyaltyTransactionType.ADJUSTMENT,
                LoyaltyReferenceType.MANUAL_ADJUSTMENT, null, null, null, null, actorUserId, reason);
    }

    /**
     * Expires exactly one overdue lot's own remaining points -- called by
     * {@code LoyaltyExpirationJob}'s daily sweep, one lot at a time.
     * Unlike {@link #consume}, this never touches any other lot: a lot's
     * {@code expiresAt} doesn't have to line up with FIFO earn order (a
     * program's policy can change over time), so expiration must target
     * the specific overdue lot, not "whatever's oldest". Returns how many
     * points were actually expired (0 if the lot was already drained by a
     * redemption that beat this sweep to it).
     */
    @Transactional
    public int expireLot(UUID lotId) {
        LoyaltyEarnLot lot = earnLotRepository.findById(lotId).orElse(null);
        if (lot == null || lot.getPointsRemaining() <= 0) {
            return 0;
        }
        Instant now = clock.instant();
        LoyaltyAccount account = lockAccount(lot.getProviderId(), lot.getUserId(), now);
        // Re-read after taking the account lock -- a concurrent redemption may have already drained this lot.
        LoyaltyEarnLot fresh = earnLotRepository.findById(lotId)
                .orElseThrow(() -> new IllegalStateException("Loyalty earn lot disappeared during expiration: "
                        + lotId));
        int amount = Math.min(fresh.getPointsRemaining(), account.getPointsBalance());
        if (amount <= 0) {
            return 0;
        }
        fresh.consume(amount);
        earnLotRepository.save(fresh);

        account.debit(amount, LoyaltyTransactionType.EXPIRED, now);
        accountRepository.save(account);

        LoyaltyTransaction tx = LoyaltyTransaction.create(lot.getProviderId(), lot.getUserId(),
                LoyaltyTransactionType.EXPIRED, -amount, account.getPointsBalance(), "Points expired",
                LoyaltyReferenceType.LOT_EXPIRATION, lot.getId(), null, null, null, null, now, null);
        transactionRepository.save(tx);
        return amount;
    }

    /** Keeps {@link LoyaltyAccount#getCompletedVisits()} in sync with a freshly-recounted total -- see its own doc comment. */
    @Transactional
    public void syncCompletedVisits(UUID providerId, UUID userId, int completedVisits) {
        Instant now = clock.instant();
        LoyaltyAccount account = lockAccount(providerId, userId, now);
        account.syncCompletedVisits(completedVisits, now);
        accountRepository.save(account);
    }

    private LoyaltyAccount lockAccount(UUID providerId, UUID userId, Instant now) {
        accountRepository.insertIfAbsent(UUID.randomUUID(), providerId, userId, now);
        return accountRepository.lockByProviderIdAndUserId(providerId, userId)
                .orElseThrow(() -> new IllegalStateException("Loyalty account missing immediately after insert: "
                        + providerId + "/" + userId));
    }

    private LoyaltyTransaction creditLocked(LoyaltyAccount account, LoyaltyTransactionType type, int points,
            String reason, LoyaltyReferenceType referenceType, UUID referenceId, UUID bookingId, UUID rewardId,
            UUID redemptionId, UUID actorUserId, Instant now, Instant expiresAt) {
        account.credit(points, now);
        accountRepository.save(account);

        LoyaltyTransaction tx = LoyaltyTransaction.create(account.getProviderId(), account.getUserId(), type, points,
                account.getPointsBalance(), reason, referenceType, referenceId, bookingId, rewardId, redemptionId,
                actorUserId, now, expiresAt);
        tx = transactionRepository.save(tx);
        earnLotRepository.save(new LoyaltyEarnLot(UUID.randomUUID(), account.getProviderId(), account.getUserId(),
                tx.getId(), points, now, expiresAt));
        return tx;
    }

    private int applyEarningCaps(LoyaltyProgram program, UUID providerId, UUID userId, int points, Instant now) {
        if (program == null) {
            return points;
        }
        int capped = points;
        if (program.getDailyEarningPointsCap() != null) {
            int earnedToday = transactionRepository.sumPointsSince(providerId, userId, EARNING_TYPES,
                    now.minusSeconds(24L * 3600));
            capped = Math.min(capped, Math.max(0, program.getDailyEarningPointsCap() - earnedToday));
        }
        if (program.getMonthlyEarningPointsCap() != null) {
            int earnedThisMonth = transactionRepository.sumPointsSince(providerId, userId, EARNING_TYPES,
                    now.minusSeconds(30L * 24 * 3600));
            capped = Math.min(capped, Math.max(0, program.getMonthlyEarningPointsCap() - earnedThisMonth));
        }
        return capped;
    }

    private static final List<LoyaltyTransactionType> EARNING_TYPES = List.of(LoyaltyTransactionType.EARNED,
            LoyaltyTransactionType.BONUS);

    static Instant computeExpiry(LoyaltyProgram program, Instant now) {
        if (program == null || !program.isPointsExpireEnabled() || program.getPointsExpirationMonths() == null) {
            return null;
        }
        return now.atZone(ZoneOffset.UTC).plusMonths(program.getPointsExpirationMonths()).toInstant();
    }
}
