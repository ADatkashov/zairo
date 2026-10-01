# ADR-0007: Marketplace Commission, Business Settlement, and Reconciliation

## Статус

Принято (discovery + design + implementation) — 2026-09-19. Builds directly
on ADR-0006 (`0006-payment-provider-freedompay.md`), which this ADR does not
repeat or re-decide: the payment/webhook/refund architecture, the classic
`pg_*` API choice, MD5 signing, idempotency, and every "Remaining Provider
Question" ADR-0006 left open are unchanged and still apply. This ADR adds
exactly one new concern ADR-0006 didn't cover: **what happens to the money
after a booking payment succeeds** — ZAIRO's commission, the business's
share, and when/how the business actually gets paid.

## Research Limitation (read this before "Why this model")

ADR-0006's research could read full Freedom Pay documentation pages
directly. **This pass could not** — `freedompay.kz` and `docs.freedompay.kz`
are blocked by this session's own network egress policy (confirmed: the
agent proxy returns `EGRESS_BLOCKED` for both hosts). Every Freedom Pay fact
below came from public search-engine result snippets only — indexed
summaries of those same pages, not the authoritative text itself. This is a
**materially weaker evidence base** than ADR-0006's, and every conclusion
below is qualified accordingly. Where a snippet didn't give field-level
detail, this ADR says so and opens a question rather than filling the gap
with a plausible-sounding guess — exactly what the task this ADR was
written for explicitly forbids ("не придумывай API Freedom Pay").

If a future engineer has real access to `docs.freedompay.kz` (or a Freedom
Pay merchant panel/support contact), re-running this research with full page
access is the single highest-value next step before this ADR's "Known
Limitations" are taken as final.

## Context

The task this ADR was written for asks for a real answer to one question:
can Factory (ZAIRO) split a single customer payment so that the business
gets its share only after the service is actually delivered, and ZAIRO
never has to act as the business's bank? ADR-0006 built the payment/refund
plumbing but never addressed commission, business payout, or settlement —
today, a SUCCEEDED payment just... sits there. ZAIRO's classic Freedom Pay
merchant account (one `pg_merchant_id`) receives the customer's full
payment, and nothing in the codebase computes what the business is owed or
pays it out.

## What This Pass Could Confirm About Freedom Pay Marketplace/Split Capability

Answering the task's Phase 2 questions A-H, from what search snippets of
Freedom Pay's own published pages actually said (not from general industry
knowledge of "how split payments usually work" — that would be exactly the
kind of invented-API risk this ADR is trying to avoid):

- **A newer API generation exists, distinct from the classic `pg_*` family
  ADR-0006 chose and this codebase already implements.** Search results
  surfaced `freedompay.kz/docs/merchant-api/*` and `freedompay.kz/docs/gateway-api/*`
  — a "Merchant API"/"Gateway API" pair authenticating via a **JWS token in
  an `X-JWS-Signature` header** (HS256/HS512), not the MD5 `pg_sig` this
  integration uses. This is at least a third distinct Freedom Pay API
  surface (classic `pg_*`, the `/v5/merchant` JWT surface ADR-0006 already
  flagged, and this JWS one) — confirms ADR-0006's "Freedom Pay may be
  mid-migration between incompatible generations" risk rather than
  resolving it.
- **A documented "Payout" (Выплаты) endpoint exists** under this newer
  Gateway API, with a confirmed **separate test host**:
  `POST https://api.freedompay.kz/g2g/payout_status` (production) and
  `POST https://test-api.freedompay.kz/g2g/payout_status` (test) — this
  partially answers ADR-0006's Open Question #2 (a sandbox host really
  does exist), but only for this newer API family; whether the classic
  `pg_*` API this codebase actually uses has the same `test-api.freedompay.kz`
  host was not confirmed by anything this pass could access.
- **Only the payout *status-check* response fields were confirmed**:
  `pg_type`, `pg_payment_id`, `pg_order_id`, `pg_status`, `pg_salt`,
  `pg_sig`. **The payout *initiation* request's fields — how a recipient
  bank account/card/IBAN is specified, what identifies the business as the
  recipient — were not found in any accessible snippet.** Implementing a
  call to whatever this endpoint's real initiation request looks like
  would be exactly the fabricated-API risk this task explicitly forbids.
- **"Payment splitting" ("Сплитование платежей") is described only as a
  marketing/product concept**, not as field-level API documentation:
  Freedom Pay's own blog content (paraphrased from search snippets)
  describes money moving through a "transit account" (транзитный счёт)
  before being automatically divided among suppliers minus commission —
  but no request/response shape, no confirmation of whether this is
  self-service via API versus a bespoke contract Freedom Pay's business
  team sets up per marketplace, and no confirmation of whether it applies
  to the classic `pg_*` API this codebase uses at all.
- **Legal/merchant structure**: Freedom Pay's own public offer describes
  itself as a payment "System Operator" processing card payments **"in
  favor of the Merchant"** ("в пользу мерчанта") under a bilateral
  Operator↔Merchant contract, with the Merchant paying the Operator a fee
  per that contract. This is a single-merchant relationship shape — no
  documented submerchant/per-partner onboarding, KYC, or account
  provisioning flow was found.

**Bottom line, answering the task's lettered questions directly:**

| # | Question | Answer |
|---|---|---|
| A | Can ZAIRO collect 15,000 once and have Freedom Pay itself route 1,500/13,500 without ZAIRO's own account receiving all 15,000 first? | **Not confirmed.** Freedom Pay's split/marketplace product may support this in principle (per its marketing description), but no field-level API confirms it works this way for a merchant on the classic `pg_*` API this codebase already integrates. |
| B | Can settlement be delayed until Booking COMPLETED? | **Not confirmed at the Freedom Pay level** — nothing found suggests Freedom Pay's own settlement-to-merchant timing is controllable per-transaction. **Achieved instead entirely at the application layer** — see "Decision" below. |
| C | Where do funds sit before settlement? | **In ZAIRO's own Freedom Pay merchant settlement account** — the same account ADR-0006 already established as the payment destination. Not a Freedom-Pay-run escrow; nothing found supports calling it one. |
| D | What happens to refund before payout? | Unchanged from ADR-0006 — `PaymentsService.refundPayment`, same as any SUCCEEDED payment. |
| E | What happens to refund after payout? | **Blocked in code** once the business's `BusinessPayout` reaches `PROCESSING`/`PAID` — see "Refund/Payout Interaction". Not supported by any confirmed provider reversal call. |
| F/G | How does Freedom Pay identify each business — separate submerchant account required? | **Not confirmed** — no documented per-business account/submerchant provisioning flow found. |
| H | Who is merchant of record? | **ZAIRO** — one `pg_merchant_id`, unchanged from ADR-0006. Every Provider (business) on the platform transacts under ZAIRO's own merchant identity, not its own. |

## Decision

**Do not implement a fabricated Freedom-Pay-native split.** Continue
ADR-0006's already-implemented, already-confirmed classic `pg_*`
single-merchant model unchanged: the customer pays the full booking price
into ZAIRO's own Freedom Pay merchant account. On top of that confirmed
foundation, add a purely internal (ZAIRO-side) commission/settlement layer:

1. The moment a `Payment` reaches `SUCCEEDED`, compute and persist a
   `PaymentAllocation` — how much is the business's share, how much is
   ZAIRO's commission (see "Commission Calculation").
2. The business's share is **not** paid out at payment time. A
   `BusinessPayout` row is created only once the booking reaches
   `COMPLETED` (see "Settlement Lifecycle") — this is how "business gets
   paid after successful service completion" is actually achieved, entirely
   in Factory's own application logic, independent of whatever Freedom
   Pay's own settlement timing to ZAIRO happens to be.
3. Because no confirmed Freedom Pay API can push money from ZAIRO to a
   business's bank account today (see "What This Pass Could Confirm"
   above), the payout itself is **a manual bank transfer a platform admin
   performs outside this system**, recorded here via an admin-only API
   (`BusinessPayoutAdminController`). This is the task's own explicitly
   sanctioned fallback: *"найди ближайшую официально поддерживаемую
   модель и чётко документируй отличие"* — the nearest real capability is
   "ZAIRO's own settled funds, moved by a human, with the outcome tracked
   in the same state machine a real provider payout would use" — not a
   pretend automatic settlement.

**This is a deliberate, documented compromise, not a hidden one.** See
"Known Limitations" for exactly what it means for ZAIRO's stated goal of
never being the customer's bank.

## Domain Model

Two new tables/entities, both in the existing `payments` module (no new
bounded-context module — this is payment-adjacent bookkeeping, not a new
subsystem, per the task's own "don't build a second payment subsystem"
instruction):

- **`PaymentAllocation`** (`payment_allocation`, keyed by `payment_id`) —
  how one `SUCCEEDED` payment split. Created once, never mutated
  afterward, even by a later refund (see `PaymentAllocation`'s own doc
  comment). Snapshots the commission rate actually applied at the time,
  independent of later config changes.
- **`BusinessPayout`** (`business_payout`, keyed by `id`, unique
  `booking_id`) — the business's own settlement record, with its own
  state machine (`BusinessPayoutStatus`: `PAYABLE -> PROCESSING -> PAID`,
  or `-> FAILED` and retriable) — deliberately not folded into `Payment`
  or `PaymentStatus` (see docs/PAYMENT_STATE_MACHINE.md and the task's own
  "не смешивай Payment и Booking в одну простую status-переменную",
  extended here to settlement).

Neither table replaces or duplicates anything ADR-0006 already built —
`Payment`, `PaymentWebhookEvent`, and their refund handling are untouched.

## Commission Calculation

`CommissionCalculator` (payments module) applies one platform-wide rate
(`payment.commission.rate`, default `0.10`) to a payment's authoritative
amount — never a client-supplied amount (see "Security"). Rounds only the
platform fee (to the currency's own minor-unit precision, via
`java.util.Currency`) and derives the business amount by subtracting it
from the total — this guarantees `businessAmount + platformFee == amount`
by construction, not by chance; `PaymentAllocation`'s constructor still
asserts it and throws rather than persist a mismatch (the task's "fail
fast" requirement).

```
15,000 KZT × 10% = 1,500.00 KZT platform fee (rounded)
15,000 KZT − 1,500.00 KZT = 13,500.00 KZT business amount
```

No per-business or per-service override exists yet — the same "don't
build for a hypothetical requirement" principle this codebase already
applies elsewhere (see `PaymentsService.createPayment`'s own doc comment
on deposit-vs-full-payment splitting).

## Settlement Lifecycle

```
Booking CONFIRMED (payment SUCCEEDED, PaymentAllocation exists)
      │
      ▼
Provider owner marks booking COMPLETED (BookingService.completeBooking)
      │  publishes BookingCompletedEvent (already existed, ADR-0002 — had no listener before this ADR)
      ▼
BookingCompletedPayoutListener (AFTER_COMMIT, REQUIRES_NEW — same pattern as
BookingCancelledPaymentListener)
      │
      ▼
BusinessPayout(PAYABLE) created — amount = PaymentAllocation.businessAmount
      │
      ▼
Platform admin performs the actual bank transfer (outside this system)
      │
      ▼
POST /platform/payouts/{id}/mark-paid (providerReference = bank transfer id)
      │
      ▼
BusinessPayout(PAID) — terminal
```

A booking that never reaches `COMPLETED` (cancelled, refunded, no-show)
never gets a `BusinessPayout` row at all — there is nothing to pay out for
a service that was never delivered. `BusinessPayoutService.createPayableForCompletedBooking`
is idempotent (booking_id is unique) and defensively no-ops (logs a
warning, does not throw) if it's ever reached for a booking whose payment
isn't SUCCEEDED or has no allocation yet — both should be unreachable given
`BookingService.completeBooking`'s own CONFIRMED-only guard, but a listener
failing loudly for an "impossible" case would roll back a booking
completion that has nothing to do with payouts.

## Refund/Payout Interaction

`PaymentsService.refundPayment` now rejects a refund (`409`, same
`PaymentConflictException` as every other invalid transition) once the
payment's `BusinessPayout` has reached `PROCESSING` or `PAID` — the money
is leaving or has left ZAIRO's control for a transfer this integration has
no confirmed provider-side reversal for. This is the task's own "`SETTLED
→ REFUNDED` must go through a supported provider reversal flow, not a
plain status flip" requirement, applied honestly: since no such reversal
flow is confirmed, the safe behavior is to block, not to fake success.
Refunding a `PAYABLE` (not yet processing) payout's payment still works
exactly as ADR-0006 already built it — nothing changes before a payout is
actually acted on.

## Reconciliation

`PaymentReconciliationService.reconcile(paymentId)` — the task's Phase 16
"ZAIRO DB vs Freedom Pay" comparison. Calls `PaymentProvider.getPaymentStatus`
(a port method ADR-0006 already added but nothing called until now) and
compares its answer against `Payment.status`, returning `MATCH` or
`DISCREPANCY`. **Never writes anything** — a discrepancy is surfaced to a
platform admin (`POST /platform/payments/{id}/reconcile`), never silently
"corrected" (the task's explicit "нельзя молча исправлять финансовые
данные"). See docs/PAYMENT_RECONCILIATION.md for the full contract,
including why `PENDING` deliberately does **not** treat a provider
`SUCCEEDED`/`FAILED` answer as a match (that's precisely the "webhook never
arrived" case this exists to catch).

This is on-demand (one payment per call), not yet a scheduled sweep across
every open payment — see "Known Limitations".

## Security

- Commission/allocation amounts are computed exclusively from the
  authoritative `Payment.amount` (itself sourced from `Booking.totalPrice`,
  itself sourced from `ServiceOffering.price` — see `BookingService.createBooking`'s
  own doc comment on why a client-supplied price is already ignored). No
  new client input is trusted anywhere in this ADR's code.
- `BusinessPayoutController` (business-facing, read-only) reuses
  `ProviderOwnership.requireOwner` — the same "does this caller own this
  provider" check every other business-facing endpoint in this codebase
  already uses. A business can list only its own payouts.
- Every payout mutation (`mark-processing`/`mark-paid`/`mark-failed`) is
  PLATFORM_ADMIN-only (`PlatformCurrentAdmin.requirePlatformAdmin`) — a
  business can see that it's owed money but never mark itself paid, the
  same "customer never sets their own refund amount" principle applied to
  the other side of the marketplace.
- `BusinessPayout.providerReference` is free text, intentionally never
  validated for shape — it's audit trail for whatever a human actually did
  (a bank transfer reference today), not a field this code parses or acts
  on.

## Testing

- `CommissionCalculatorTest`/`PaymentAllocationTest` (payments module,
  no Spring context) — the task's own worked example (15,000/1,500/13,500),
  rounding correctness, the fail-fast amount-mismatch/negative guards.
- `BusinessSettlementApiTests` (platform-api, Testcontainers/Postgres) —
  full lifecycle: pay a booking, confirm the allocation appears with the
  correct split, complete the booking, confirm the payout appears only
  then, provider-ownership isolation (one business can't see another's
  payouts), admin mark-paid and its terminal-state guard, refund blocked
  once a payout is PAID, and a reconciliation call matching the mock
  provider.

## Known Limitations (not masked)

- **ZAIRO is the sole merchant of record and does, operationally, receive
  the business's share into its own settlement account before paying it
  out.** This is in real tension with the task's stated goal ("не делать
  ZAIRO самостоятельным кошельком") — the honest state of this
  integration is that ZAIRO briefly custodies 100% of every payment
  between charge and manual payout, which is closer to "ZAIRO as
  intermediary" than to a true marketplace/split arrangement where funds
  never touch ZAIRO's own balance for the business's portion. Closing this
  gap requires either (a) confirming and integrating whatever Freedom
  Pay's real split/marketplace product actually is (Open Questions below),
  or (b) a different provider/product that documents this explicitly.
  **Do not present the current implementation as escrow or as
  submerchant settlement — it is neither.**
- **Business payout is a manual bank transfer, not an automated Freedom
  Pay API call.** `BusinessPayoutAdminController.markPaid` records that a
  human moved the money; nothing in this codebase calls a Freedom Pay
  payout-initiation endpoint (its request fields aren't confirmed — see
  above). Acceptable for the task's own "1-2 real businesses" pilot scale
  (ADR-0006), not for a larger business count without either automating
  this or accepting the ongoing manual-ops cost.
- **Reconciliation is on-demand, not a scheduled sweep.** A payment stuck
  in a bad state is only caught when a platform admin explicitly reconciles
  it.
- Every ADR-0006 open question/limitation (recurring charge unconfirmed,
  refund endpoint choice, fiscal receipt data, Result-notify script name,
  response-signing) is unchanged and still applies — this ADR does not
  revisit any of them.

## Open Questions (require direct Freedom Pay merchant-panel/support access)

1. Does Freedom Pay's real, contracted split/marketplace product allow a
   merchant to receive funds pre-split, without the aggregator (ZAIRO)
   ever holding the business's share? This needs Freedom Pay's business
   team, not public docs — the public material found is marketing-level,
   not an API spec.
2. What are the exact request fields for G2G payout *initiation*
   (`https://api.freedompay.kz/g2g/payout` — only `payout_status`'s
   response fields were confirmed)? Specifically: how is the recipient
   (bank account/card) specified, and how would each Provider's payout
   destination be provisioned/verified (KYC)?
3. Does the confirmed `test-api.freedompay.kz` sandbox host apply to the
   classic `pg_*` API this codebase actually uses, or only to the newer
   Gateway/Merchant API (JWS-signed) family?
4. What KYC/onboarding does Freedom Pay require per business if a real
   submerchant/split arrangement is pursued later?
5. All of ADR-0006's original open questions (1-6) remain unresolved and
   are inherited unchanged.

Nothing above blocks what this ADR actually implements: the commission
split, the completion-gated payout lifecycle, and the manual-settlement
fallback are all real, working, and honestly scoped to what this pass
could confirm — they do not depend on any of these open questions
resolving in a particular direction.
