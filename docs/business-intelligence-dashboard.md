# Business Intelligence Dashboard

A business owner's Revenue Intelligence Dashboard — what the business earned, what
ZAIRO recovered, what's at risk, and what deserves attention next. Extends the
existing `provider-insights` module rather than duplicating Revenue Engine, Smart
Fill, or Customer Intelligence.

## Architecture

Same "read-composition, computed live, no persisted aggregate table" discipline
`ProviderInsightsService`/`PlatformInsightsService` already use — see those
modules' own doc comments. All new logic lives in
`backend/provider-insights/.../BusinessAnalyticsService.java`, which composes:

- `BookingRepository`/`AvailabilitySlotRepository`/`PaymentRepository` (own module
  dependencies) for booking mix, revenue, and utilization.
- `SmartFillAnalyticsService.performance(providerId, from, to)` — a new date-scoped
  overload of the existing method, not a re-implementation.
- `RevenueAttributionService.summary(providerId, from, to)` — same, a date-scoped
  overload of the existing "Revenue Recovered by ZAIRO" ledger read.
- `CustomerProviderProfileRepository.findByProviderId(providerId)` — Customer
  Intelligence's existing per-business profiles, aggregated here for the first
  time into business-level retention/value rollups. No new customer-intelligence
  tables or calculators; only its already-computed data.

No new database tables or Flyway migrations were needed.

## Endpoints

All owner-only (`ProviderOwnership.requireOwner` + `CurrentUser.requireUserId`,
the same pattern every other `provider-insights` endpoint uses):

| Endpoint | Returns |
|---|---|
| `GET /api/v1/providers/{id}/analytics/overview?from=&to=` | `BusinessAnalyticsDtos.OverviewResponse` |
| `GET /api/v1/providers/{id}/analytics/revenue?from=&to=` | `RevenueAnalyticsResponse` |
| `GET /api/v1/providers/{id}/analytics/bookings?from=&to=` | `BookingAnalyticsResponse` |
| `GET /api/v1/providers/{id}/analytics/smart-fill?from=&to=` | `smartfill.SmartFillDtos.SmartFillPerformanceResponse` (reused, not duplicated) |
| `GET /api/v1/providers/{id}/analytics/customers?from=&to=` | `CustomerAnalyticsResponse` |
| `GET /api/v1/providers/{id}/analytics/actions` | `ActionCenterResponse` (not date-scoped — current state) |
| `GET /api/v1/providers/{id}/analytics/smart-fill/active` | `smartfill.SmartFillDtos.CampaignSummary[]` — Action Center's Smart Fill drill-down, not date-scoped |
| `GET /api/v1/providers/{id}/analytics/customers/list?retentionStatus=` | `CustomerListItem[]` — Action Center's rebook/retention drill-down, not date-scoped |

The existing `/dashboard`, `/customers`, `/smart-fill/performance`, and
`/revenue-engine/summary` endpoints are unchanged and still lifetime-scoped —
the new `/analytics/*` endpoints are additive.

## Date range

`from`/`to` are optional ISO-8601 instants. When omitted, they default to the
start of the current UTC calendar month through now
(`BusinessAnalyticsService.resolveRange`). `from >= to` is rejected with 400. The
Flutter client always sends explicit UTC bounds for its Today/This week/This
month/Custom chips so the displayed range and the requested range always agree.

Some fields are deliberately **not** range-scoped even on a ranged endpoint,
because the underlying relationship spans a customer's whole history, not one
reporting period — documented per-field in `BusinessAnalyticsDtos` (e.g.
`OverviewResponse.returningCustomerRate`, most of `CustomerAnalyticsResponse`
except `newCustomers`).

## Metrics that are honestly "unavailable" rather than invented

- **Utilization** (`OverviewResponse.utilization`): booked slot duration ÷
  offered slot duration, from real `AvailabilitySlot` rows in range. `null` — not
  `0` — when this provider has no availability slots starting in range, so the
  UI shows "not available yet" instead of a misleading number.
- **Revenue** is always the sum of `SUCCEEDED` payments, never a booking's quoted
  price. A cancelled or unpaid booking never contributes to any revenue figure.
- **Recovered revenue** is the Decision Engine's own outcome ledger
  (`RevenueOutcome`, `recovered = true` rows only) — never inferred from Smart
  Fill campaign status.

## Action Center

Deterministic, rule-based signals only (`BusinessAnalyticsService.actions`) — no
generated/AI recommendations:

- **Smart Fill opportunity** — count of this provider's Smart Fill campaigns
  still in `CREATED`/`SEARCHING`/`NOTIFYING` (excludes `BOOKED`/`EXPIRED`/`CANCELLED`).
- **Rebook opportunity** — count of `CustomerProviderProfile` rows with
  `RetentionStatus.DUE_FOR_REBOOKING`.
- **Retention risk** — count with `RetentionStatus.AT_RISK`.
- **Low utilization** — tomorrow's booked/offered slot ratio, if below 30% and
  slots exist for tomorrow.

Each item is a `{type, count}` pair — no server-rendered text. The Flutter client
owns the localized copy per `ActionItemType` (`app_{en,ru,kk}.arb`), so future
Decision Engine strategies can add a new `ActionItemType` branch without any
backend string work. Extending it: add an enum value to
`BusinessAnalyticsDtos.ActionItemType`, one branch in
`BusinessAnalyticsService.actions`, and a matching localized string + icon case
in `business_analytics_screen.dart`'s `_ActionCard`.

Every Action Center card is tappable and opens the real data behind its count
(`_ActionCard._onTap`):

- **Smart Fill opportunity** → `SmartFillCampaignsScreen`, backed by
  `SmartFillAnalyticsService.activeCampaigns` / `GET .../analytics/smart-fill/active`
  — the same active-campaign set the count itself comes from, not a
  re-derived approximation.
- **Rebook opportunity** / **Retention risk** → `CustomerListScreen`, backed by
  `BusinessAnalyticsService.customersList` / `GET .../analytics/customers/list?retentionStatus=`
  — filtered to exactly `DUE_FOR_REBOOKING` / `AT_RISK` respectively.
- **Low utilization** → pops back to `SalonDetailScreen`, which already shows
  this business's availability/schedule section (no dedicated "schedule for
  one day" screen exists yet).

Both drill-down screens are read-only (list the affected campaigns/customers),
since no per-campaign "manage" action or in-admin rebooking workflow exists
yet in this app.

## Authorization & cross-business isolation

Every endpoint calls `providerOwnership.requireOwner(providerId, callerUserId)`
before touching any data — 404 if the provider doesn't exist, 403 if it exists
but belongs to someone else. No endpoint trusts `providerId` from the request
beyond that check; every repository query is additionally scoped by
`providerId` itself (never returns another business's rows even if ownership
were somehow bypassed).

## Flutter (business_admin app)

- `features/salon/data/models/business_analytics.dart` — response models.
- `features/salon/data/salon_admin_api.dart` — `fetchAnalytics*` methods.
- `features/salon/presentation/providers/salon_providers.dart` —
  `businessAnalytics{Overview,Revenue,Bookings,SmartFill,Customers,Actions}Provider`,
  keyed by `(providerId, AnalyticsRange)`.
- `features/salon/presentation/screens/business_analytics_screen.dart` — the
  dashboard screen (Today/This week/This month/Custom chips, KPI tiles, revenue
  and booking trend bars, Smart Fill and Customer Intelligence sections, Action
  Center). Opened from `SalonDetailScreen`'s AppBar (insights icon).
- `features/salon/presentation/screens/smart_fill_campaigns_screen.dart` /
  `customer_list_screen.dart` — the Action Center's drill-down screens.
- No new chart library dependency — day-by-day trends use a small proportional
  `LinearProgressIndicator`-based bar row (`_BarRow`), not a fabricated chart.
- Localized in en/ru/kk; no hardcoded UI strings.

## PRO monetization readiness

Not gated in this v1 per the initial scope, but every section is a separate
endpoint/provider/widget, so gating any one of them later (e.g. Smart Fill
analytics, Customer Intelligence, revenue-recovered) is a
`SubscriptionLimitService.checkXyzAllowed(ownerUserId)` call at the top of the
relevant controller method — the same pattern `checkRecurringScheduleAllowed`
already uses — plus a client-side `BillingException` catch, without changing
any other section.

## Known limitations / follow-ups

- Action Center drill-down screens are view-only — no "manage campaign" action
  and no in-admin rebooking workflow, since neither exists yet in this app.
  Adding either is a natural follow-up; the drill-down screens and endpoints
  are already in place to extend.
- `revenueByStaff`/favourite-staff use the opaque `employeeId` from
  `AvailabilitySlot`/`CustomerProviderProfile` (no cross-module name lookup,
  matching this codebase's existing convention of not coupling core modules to
  each vertical's own Master/Mechanic/Cleaner entity) — the Flutter UI shows
  favourite services (which do have display names) and omits a favourite-staff
  list rather than showing a bare UUID.
- Backend integration tests (`BusinessAnalyticsApiTests`) require a real
  Postgres via Testcontainers/Docker; they compile and follow this repo's
  established test conventions but could not be executed in a Docker-less
  sandbox during development — run them in CI.
