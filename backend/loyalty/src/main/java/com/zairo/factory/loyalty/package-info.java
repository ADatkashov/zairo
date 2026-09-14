/**
 * Loyalty &amp; Rewards: lets a business run its own points program and
 * lets customers earn, track, and redeem points with that business.
 *
 * <h2>Business-scoped, never pooled</h2>
 * A {@link com.zairo.factory.loyalty.LoyaltyAccount} is keyed on
 * ({@code providerId}, {@code userId}) -- a customer's balance with
 * Beauty Salon A is a completely separate row from their balance with
 * Dental Clinic B, with its own {@link com.zairo.factory.loyalty.LoyaltyProgram}
 * rules, its own {@link com.zairo.factory.loyalty.LoyaltyReward} catalog, and
 * its own ledger. Nothing in this module ever sums balances across
 * providers or lets a reward from one business be redeemed against
 * another's points -- every query, lock, and constraint is scoped by
 * {@code providerId} first. {@link com.zairo.factory.loyalty.LoyaltyController}'s
 * "my rewards" endpoint composes a customer's own accounts across every
 * business into one list purely for display; a future platform-wide
 * reward would be a new, explicitly cross-business concept layered on top,
 * not a change to how this module isolates today's balances.
 *
 * <h2>Immutable ledger, mutable cache</h2>
 * {@link com.zairo.factory.loyalty.LoyaltyTransaction} is the append-only
 * source of truth -- every balance change is a new row (EARNED, BONUS,
 * REDEEMED, EXPIRED, REFUND, ADJUSTMENT, REVERSAL), never an edit to an
 * existing one. {@link com.zairo.factory.loyalty.LoyaltyAccount#getPointsBalance()}
 * is a cached running total kept in lock-step with the ledger inside the
 * same transaction (see {@link com.zairo.factory.loyalty.LoyaltyLedgerService}),
 * so reads stay O(1) instead of re-summing history on every request (Money
 * as a concept, not literally {@code money.Money} -- points aren't
 * currency and never flow through payments).
 *
 * <p>Point expiry is FIFO over {@link com.zairo.factory.loyalty.LoyaltyEarnLot}
 * rows: each earning transaction opens one lot with its own {@code
 * expiresAt} (from the program's expiration policy at the time the points
 * were earned) and a mutable {@code pointsRemaining} that redemptions and
 * the expiration sweep both decrement, oldest lot first. The lot table is
 * bookkeeping, not the audit trail -- {@code loyalty_transaction} still
 * records every EARNED/REDEEMED/EXPIRED event in full; lots just make "which
 * points are about to expire" and "expire the oldest points first" cheap
 * to compute without re-deriving them from the whole ledger.
 *
 * <h2>Concurrency-safe redemption</h2>
 * {@link com.zairo.factory.loyalty.LoyaltyLedgerService#consume} takes a
 * pessimistic write lock on the account row for the whole redeem-or-expire
 * operation (see {@link com.zairo.factory.loyalty.LoyaltyAccountRepository#lockByProviderIdAndUserId}) --
 * two concurrent redemption requests for the same nearly-exhausted balance
 * serialize instead of racing to a negative balance. {@link
 * com.zairo.factory.loyalty.LoyaltyRedemptionRepository#lockByCode} gives
 * the same guarantee to the ACTIVE-status transition itself (apply-to-
 * booking, cancel) -- two concurrent applies/cancels of the same code
 * serialize instead of both observing ACTIVE (Phase 0 stabilization).
 * Duplicate earning (the same booking's completion event firing twice, a
 * retried outbox row, an application restart mid-sweep, ...) is idempotent
 * by construction: {@link com.zairo.factory.loyalty.LoyaltyLedgerService#earn}
 * takes the account lock first, then checks {@code
 * existsByProviderIdAndUserIdAndReferenceTypeAndReferenceId} under that
 * lock -- a second award for the same {@code (referenceType, referenceId)}
 * always sees the first one's already-committed row and safely no-ops.
 * Partial unique indexes on {@code loyalty_transaction} (see V57) are the
 * database-level backstop behind that same-process guarantee, not the
 * primary mechanism.
 *
 * <h2>Durable, retried earning -- transactional outbox</h2>
 * {@link com.zairo.factory.loyalty.LoyaltyEarningListener} reacts to
 * {@code booking.BookingCompletedEvent} and {@code reviews.ReviewCreatedEvent}
 * (ADR-0002) -- booking and reviews have no idea this module exists. It does
 * the least possible work: writing one {@link
 * com.zairo.factory.loyalty.LoyaltyOutboxEvent} row, inside the SAME
 * transaction as the booking/review write (a plain, non-{@code
 * AFTER_COMMIT} listener), so the row is as durable as the fact it
 * records. {@link com.zairo.factory.loyalty.LoyaltyOutboxProcessor} then
 * runs the actual earning computation ({@link
 * com.zairo.factory.loyalty.LoyaltyEarningProcessor}) every 15 seconds
 * against PENDING rows, retrying on failure (DB hiccup, app restart mid-
 * sweep -- the row is still PENDING on the next tick) up to {@link
 * com.zairo.factory.loyalty.LoyaltyOutboxProcessor#MAX_ATTEMPTS} times
 * before dead-lettering it. Safe to retry because {@code earn()} is
 * idempotent (above) -- this is the "transactional event/outbox -&gt;
 * retryable processing -&gt; idempotent earning" shape, sized to what
 * Postgres + a scheduled job can do alone, no broker needed (ADR-0002).
 * Cancelled/no-show bookings publish no completion event, so they simply
 * never earn anything; there is nothing to reverse. A booking whose price
 * was reduced by an applied loyalty reward is a business-admin action
 * recorded on {@link com.zairo.factory.loyalty.LoyaltyRedemption} itself
 * (see {@code applyToBooking}) rather than a change to {@code
 * booking.Booking}'s own stored price -- see that method's own doc comment
 * for why this iteration stops short of rewriting the booking pricing
 * pipeline.
 *
 * <h2>Deliberately not built here</h2>
 * No cross-business/platform-wide wallet (see above). No referral program
 * -- {@link com.zairo.factory.loyalty.LoyaltyLedgerService#adjust} is the
 * generic "award points for an out-of-band reason" seam a future referral
 * feature would call into, not a referral system built ahead of need. No
 * birthday bonus -- {@code users.User} has no date-of-birth field yet;
 * inventing one here would mean fabricating customer data. No rewrite of
 * {@code booking.BookingService}'s price calculation -- see above.
 */
package com.zairo.factory.loyalty;
