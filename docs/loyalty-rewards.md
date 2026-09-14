# Loyalty & Rewards

Lets a business run its own points program: customers earn points by
completing bookings (and a few configurable bonus rules) and redeem them for
that business's own reward catalog. Business-scoped, never pooled across
businesses — a customer's balance with Beauty Salon A is a completely
separate row, with its own program rules and its own reward catalog, from
their balance with Dental Clinic B. New module, `backend/loyalty`; see its
own `package-info.java` for the full design rationale (immutable ledger +
FIFO earn-lot expiry, concurrency-safe redemption via a pessimistic account
lock, and why duplicate-award protection is enforced with database partial
unique indexes rather than only an application-level check).

## New tables (`V57__create_loyalty_tables.sql`)

- `loyalty_program` — one per business: enabled/disabled, earning rules
  (fixed points per booking, points per currency unit spent, first-booking/
  repeat-visit/review bonuses), redemption rules (minimum balance, max
  points per booking), expiration policy, daily/monthly earning caps.
- `loyalty_milestone_rule` / `loyalty_tier_rule` — a business's own
  configurable "reach N visits → M bonus points" ladder and "reach N
  lifetime points → this tier" ladder. Deliberately not hardcoded
  Bronze/Silver/Gold — an empty ladder is a valid, common starting state.
- `loyalty_account` — one per (business, customer): a cached running
  balance kept in lock-step with the ledger, never the sole record of
  anything.
- `loyalty_earn_lot` — FIFO expiry bookkeeping. One row per points-adding
  transaction, with its own `expires_at` and a mutable `points_remaining`
  that redemption/expiration both decrement, oldest lot first.
- `loyalty_transaction` — the immutable ledger. Every balance change, ever,
  one row each (`EARNED`/`BONUS`/`REDEEMED`/`EXPIRED`/`REFUND`/
  `ADJUSTMENT`/`REVERSAL`), never edited after insert. Partial unique
  indexes close duplicate-award races at the database level (Phase 19 of
  the feature brief): one `BOOKING_EARNING`/`REVIEW_BONUS`/
  `REPEAT_VISIT_BONUS` per booking, one `FIRST_BOOKING_BONUS` per account
  ever, one `MILESTONE` award per (account, milestone).
- `loyalty_reward` — a business's reward catalog (fixed discount,
  percentage discount, free service, or a custom business-defined reward).
- `loyalty_redemption` — one customer's redemption of one reward: a
  spend already deducted from their account, a short lookup code, and a
  snapshot of the reward's shape at redemption time (so editing the
  catalog later never rewrites history).

Every cross-module id (`provider_id`, `user_id`, `service_id`, `booking_id`,
`actor_user_id`) is a bare `uuid` column with no FK, the same established
convention every other module here uses (see `docs/erd/core-domain.md`).

## Earning rules

Triggered off `booking.BookingCompletedEvent` and the new
`reviews.ReviewCreatedEvent` (added to `reviews` for this feature, following
the same in-process domain-event pattern as every other cross-module
listener — ADR-0002) via `LoyaltyEarningListener`. A cancelled or no-show
booking publishes no completion event, so it simply never earns anything —
there is nothing to reverse. A disabled or never-configured program means
every rule is a silent no-op: existing businesses that haven't touched
Loyalty behave exactly as before this module existed.

## Redemption and "apply to booking"

Redeeming a reward deducts points immediately (`LoyaltyLedgerService#consume`,
under a pessimistic lock on the account row — two concurrent redemption
requests against a nearly-exhausted balance serialize instead of racing to a
negative balance) and issues a short code. A business owner later looks that
code up and applies it to a specific booking of that same customer's, at
that same business (`LoyaltyRedemptionService#applyToBooking`). This
iteration deliberately stops there rather than rewriting
`booking.BookingService`'s price-calculation pipeline to actually reduce a
booking's stored total — see that method's own doc comment. The discount a
customer gets is always read from the reward's own server-held snapshot;
nothing about a redemption's value is ever client-supplied.

## Expiration

`LoyaltyExpirationJob` runs once a day (`@Scheduled(cron = "0 0 3 * * *")`,
same once-a-day cadence reasoning as `subscriptions.SubscriptionRenewalJob`)
and expires overdue `loyalty_earn_lot` rows in bounded pages ordered by
`expires_at` (indexed) rather than scanning every account's full history.
Also lazily expires unused, past-validity redemption codes. Both produce
auditable ledger rows (`EXPIRED`) — points are never silently deleted.

## Endpoints

Customer-facing (self-service only — every read/write is scoped to the
caller's own identity via `auth.CurrentUser`):

| Endpoint | Returns |
|---|---|
| `GET /api/v1/loyalty` | This customer's accounts across every business |
| `GET /api/v1/loyalty/businesses/{providerId}` | One business's program + this customer's standing |
| `GET /api/v1/loyalty/businesses/{providerId}/rewards` | That business's redeemable-now rewards |
| `GET /api/v1/loyalty/businesses/{providerId}/history` | This customer's own ledger with that business |
| `POST /api/v1/loyalty/rewards/{rewardId}/redeem` | Redeem a reward, issue a code |
| `GET /api/v1/loyalty/redemptions` / `/{id}` | This customer's own redemptions |
| `POST /api/v1/loyalty/redemptions/{id}/cancel` | Cancel an unused redemption, refund points |

Business-admin (`ProviderOwnership.requireOwner` on every call, the same
404-vs-403 pattern every other owner-only surface here uses):

| Endpoint | Returns |
|---|---|
| `GET`/`PUT /api/v1/business/{providerId}/loyalty/settings` | Program configuration |
| `GET`/`PUT /api/v1/business/{providerId}/loyalty/milestones` | Milestone ladder (full replace) |
| `GET`/`PUT /api/v1/business/{providerId}/loyalty/tiers` | Tier ladder (full replace) |
| `GET /api/v1/business/{providerId}/loyalty/overview` | Dashboard metrics |
| `GET /api/v1/business/{providerId}/loyalty/customers` / `/{userId}` | Loyalty roster (composes with `customer-intelligence`, read-only) |
| `POST /api/v1/business/{providerId}/loyalty/customers/{userId}/adjust` | Manual adjustment (reason + actor required) |
| `GET`/`POST /api/v1/business/{providerId}/loyalty/rewards`, `PUT`/`.../activate`/`.../deactivate`/`DELETE .../{rewardId}` | Reward catalog CRUD |
| `GET /api/v1/business/{providerId}/loyalty/redemptions` | This business's redemption codes |
| `POST /api/v1/business/{providerId}/loyalty/redemptions/{code}/apply` | Apply a code to a booking |
| `POST /api/v1/business/{providerId}/loyalty/redemptions/{id}/cancel` | Cancel a code, refund points |

## Customer Intelligence / Revenue Engine / Campaign Center integration

`LoyaltyCustomerInsightsService` composes a customer's already-computed
`customer-intelligence.CustomerProviderProfile` (retention status) with
their loyalty standing for the business-admin roster — read-only, one-way
dependency (`loyalty → customer-intelligence`), same shape as
`provider-insights`/`campaign-center`'s own composition over sibling
modules; `customer-intelligence` has no idea this module exists.

Deeper Revenue Engine/Campaign Center integration (loyalty-aware Smart Fill
offers, a dedicated "Loyalty Bonus"/"Expiring Points" campaign type, loyalty
metrics on the Business Intelligence Dashboard) is a deliberate follow-up,
not part of this iteration — this module exposes the read surfaces
(balances, expiring-soon sums, dashboard aggregates) those integrations
would need, without yet wiring the engines themselves, to avoid touching
three already-established, separately-owned campaign engines' lifecycle
logic in the same change that introduces the ledger they'd read from.

## Deliberately not built here

No cross-business/platform-wide wallet. No referral program —
`LoyaltyLedgerService#adjust` is the generic "award points for an
out-of-band reason" seam a future referral feature would call into. No
birthday bonus — `users.User` has no date-of-birth field yet; this module
doesn't fabricate one. No rewrite of `booking.BookingService`'s price
calculation — see "Redemption and apply to booking" above.
