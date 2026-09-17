# Campaign Center + Smart Actions

The business owner's single place to see what the Revenue Engine's automated
campaigns (Smart Fill, Rebook, Reactivation) are doing, why, and what to do
next — and to act on them (pause/resume/cancel/retry) where the underlying
engine safely supports it. Extends the existing three campaign engines and
`docs/business-intelligence-dashboard.md`'s own Action Center rather than
duplicating any of them; closes that doc's own documented gap ("no
manage-campaign action ... exists yet in this app").

## Why a composition layer, not a fourth "Campaign" table

`smartfill.SmartFillCampaign`, `rebookengine.RebookCampaign`, and
`reactivationengine.ReactivationCampaign` are three separate entities, each
owned by its own module, each with its own status enum and lifecycle rules —
there is no shared "Campaign" abstraction anywhere in this codebase (see
`revenueengine`'s own package-info: it defines the `ActionType` vocabulary
and the outcome ledger, never a campaign row itself). The new
`backend/campaign-center` module reads all three directly and composes each
into one unified `CampaignDto` shape, live, on every call — same
"computed fresh, no persisted aggregate/mirror table" discipline
`providerinsights.BusinessAnalyticsService` already established for this
exact kind of cross-module read composition. See
`campaigncenter`'s own `package-info.java` for the full rationale, including
the documented, deliberate gaps (Rebook has no distinct notification-sent
timestamp; pause/resume only exist for Smart Fill).

No new database tables. `V56__add_campaign_center_provider_indexes.sql`
adds two indexes (`rebook_campaign`/`reactivation_campaign` on
`(provider_id, created_at)`) that a provider-scoped list/stats read now
needs and previously didn't; `PAUSED`/`CANCELLED` are new values of each
table's existing `status varchar(20)` column, which has no check constraint
to migrate (see V51/V53/V54's own migration comments).

## Endpoints

All owner-only (`ProviderOwnership.requireOwner` + `CurrentUser.requireUserId`,
the same pattern every other business-scoped endpoint in this codebase uses).
`providerId` always comes from the path and is re-validated against the
caller; every action additionally re-validates the resolved campaign's own
`providerId` before touching it (a campaign id under the wrong provider 404s,
it never leaks another business's data).

| Endpoint | Returns |
|---|---|
| `GET /api/v1/providers/{id}/campaigns?type=&status=&serviceId=&employeeId=&from=&to=&search=&page=&pageSize=&newestFirst=` | `CampaignCenterDtos.CampaignListResponse` |
| `GET /api/v1/providers/{id}/campaigns/stats` | `CampaignStatsResponse` |
| `GET /api/v1/providers/{id}/smart-actions` | `SmartActionsResponse` |
| `GET /api/v1/providers/{id}/campaigns/{type}/{campaignId}` | `CampaignDto` |
| `GET /api/v1/providers/{id}/campaigns/{type}/{campaignId}/timeline` | `CampaignTimelineResponse` |
| `POST /api/v1/providers/{id}/campaigns/{type}/{campaignId}/pause` | `CampaignDto` (refreshed) |
| `POST /api/v1/providers/{id}/campaigns/{type}/{campaignId}/resume` | `CampaignDto` (refreshed) |
| `POST /api/v1/providers/{id}/campaigns/{type}/{campaignId}/cancel` | `CampaignDto` (refreshed) |
| `POST /api/v1/providers/{id}/campaigns/{type}/{campaignId}/retry` | `CampaignDto` (refreshed) |

`{type}` is `SMART_FILL`, `REBOOK`, or `REACTIVATION`.

## Unified status mapping

`CampaignStatus` (`ACTIVE`/`PAUSED`/`COMPLETED`/`EXPIRED`/`FAILED`/`CANCELLED`)
is the cross-type filter/display status; each `CampaignDto` also carries the
owning engine's own raw status name (`rawStatus`, e.g. `"NOTIFYING"`) so
nothing is lost in translation. `FAILED` is not a status any engine persists
— it's derived (an EXPIRED Smart Fill campaign that never notified a single
candidate) to distinguish "we tried and nobody booked" from "we never
managed to try," without adding a new persisted state that would need its
own migration and job-sweep awareness across three modules.

## Safe actions

Every action delegates to that campaign's own engine service
(`SmartFillCampaignService`/`RebookCampaignService`/`ReactivationCampaignService`)
— Campaign Center owns none of the three lifecycles, it only resolves which
service to call. Each is a real, minimal, idempotent command added to the
owning engine (not fabricated in this module):

- **Pause/Resume** — Smart Fill only, only while `NOTIFYING`/`PAUSED`
  respectively (the one engine with a meaningful "waiting between stages"
  state to pause). `SmartFillCampaignStatus.PAUSED` is excluded from
  `SmartFillCampaignJob`'s sweep automatically (it filters on `NOTIFYING`);
  `completeCampaignsForBookedSlot` was updated to also close out `PAUSED`
  campaigns so a paused campaign whose slot gets booked anyway (by anyone)
  still resolves correctly.
- **Cancel** — any type, any time the campaign is still active/paused. Same
  close-out its own engine already uses for a normal expiry (every
  still-open Smart Fill offer closed out, the outcome ledger resolved as
  not-recovered). Terminal — a cancelled or already-completed campaign can
  never be restarted.
- **Retry** — Smart Fill only, only for a campaign that expired never having
  recovered its slot, whose slot is still genuinely open. Re-runs the same
  candidate-discovery-and-first-stage flow the original cancellation
  triggered, continuing the same campaign's own stage numbering rather than
  creating a duplicate. Calling it on an already-active campaign, or one
  whose slot got booked meanwhile, is a no-op `409`, not a duplicate
  notification round.

`availableActions` on every `CampaignDto` is computed server-side from real
state — the client renders only the buttons present there; no action is
ever exposed that the backend can't actually execute right now.

## Smart Action Center

Deterministic, rule-based signals only (`CampaignCenterService.smartActions`)
— no generated/AI recommendations, same discipline as
`providerinsights.BusinessAnalyticsService#actions`:

- **Expiring soon** — a `NOTIFYING` Smart Fill campaign whose slot starts
  within 2 hours, still unbooked.
- **Failed / Retriable** — an `EXPIRED`, never-recovered Smart Fill campaign
  whose slot is still open (failed = never notified anyone; retriable =
  notified but nobody booked) — both carry `recommendedActions: ["RETRY"]`.
- **Rebooking opportunity / At-risk / Long-inactive** — Customer
  Intelligence's own `DUE_FOR_REBOOKING`/`AT_RISK`/`INACTIVE` per-business
  profiles, reused as-is (no new customer scoring here).

`CampaignStatsResponse.campaignsRequiringAttention` is exactly this list's
size, so the dashboard KPI and the Smart Action Center's own item count can
never disagree.

## Authorization & cross-business isolation

Identical discipline to `docs/business-intelligence-dashboard.md`'s own
section of the same name: every endpoint calls
`providerOwnership.requireOwner(providerId, callerUserId)` first, and every
campaign lookup is additionally filtered by that exact `providerId` before
being returned — a campaign id belonging to another business 404s, it's
never distinguishable from "doesn't exist."

## Flutter (business_admin app)

- `features/campaigns/data/models/campaign.dart` — response models mirroring
  the DTOs above.
- `features/campaigns/data/api/campaign_center_api.dart` — the API client.
- `features/campaigns/presentation/providers/campaign_providers.dart` —
  Riverpod family providers for list/stats/smart-actions/detail/timeline,
  plus the pause/resume/cancel/retry mutation flow.
- `features/campaigns/presentation/screens/campaign_center_screen.dart` /
  `campaign_detail_screen.dart` — the main list screen (KPI row, filters,
  paginated list, pull-to-refresh) and detail screen (summary, timeline,
  safe actions, related-entity links).
- `features/campaigns/presentation/widgets/campaign_card.dart` — the
  list-item card.
- The Business Intelligence Dashboard's existing Action Center
  (`business_analytics_screen.dart`) gained a Smart Action Center section
  backed by `/smart-actions`, using the same `_ActionCard`-style tappable
  pattern the dashboard already established.
- New Campaign Center destination wired into `admin_shell.dart`'s desktop
  sidebar and the app's mobile top-level navigation.
- Localized in en/ru/kk; no hardcoded UI strings.

## Known limitations / follow-ups

- Pause/Resume is Smart Fill-only — Rebook and Reactivation only gained
  `cancelCampaign`. Both are simpler, longer-window engines (day-granularity
  due dates, not a multi-stage notification rollout) where "pause" has no
  equally clean meaning; extending it is a natural follow-up once real usage
  shows it's wanted, not built preemptively here.
- Rebook's timeline never shows a `NOTIFICATION_SENT` event — that engine
  has no stored "offered at" timestamp, only its own status (see
  `campaigncenter`'s package-info). Reactivation's timeline does show one,
  since that engine sends its nudge at `createdAt` itself.
- `updatedAt` on a `CampaignDto` is a derived "latest known activity"
  timestamp (max of creation/notification/response/completion), not a
  stored column — none of the three engines track a generic row-level
  "last modified at."
- List/stats/Smart Actions load one business's own campaign rows into
  memory and filter/sort/paginate there (bounded by `provider_id`, never
  all campaigns platform-wide) — same discipline
  `providerinsights.BusinessAnalyticsService#customersList` already uses.
  Revisit with real per-provider volume data if this ever needs to become a
  true paginated SQL query across three tables.
- Backend integration tests (`CampaignCenterApiTests`) require a real
  Postgres via Testcontainers/Docker; they compile and follow this repo's
  established test conventions but could not be executed in a Docker-less
  sandbox during development (same documented limitation as
  `BusinessAnalyticsApiTests`) — run them in CI.
