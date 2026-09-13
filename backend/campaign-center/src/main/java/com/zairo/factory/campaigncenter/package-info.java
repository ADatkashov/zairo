/**
 * Campaign Center + Smart Actions -- the business-owner-facing surface that
 * makes the three existing campaign engines (Smart Fill, Rebook,
 * Reactivation) visible, understandable, and actionable.
 *
 * <h2>Why a composition layer, not a fourth "Campaign" table</h2>
 * {@code smartfill.SmartFillCampaign}, {@code rebookengine.RebookCampaign},
 * and {@code reactivationengine.ReactivationCampaign} are three separate
 * entities, each owned by its own module, each with its own status enum and
 * lifecycle rules. There is no shared "Campaign" abstraction anywhere in
 * this codebase (see {@code revenueengine}'s own package-info -- it defines
 * the {@code ActionType} vocabulary and the outcome ledger, but never a
 * campaign row itself). Rather than introduce a fourth table that would need
 * to be kept in sync with three others, this module reads all three
 * directly and maps each into one unified {@link
 * com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignDto} shape --
 * same "computed fresh on every call, no persisted aggregate/mirror table"
 * discipline {@code providerinsights.BusinessAnalyticsService} already
 * established for this exact kind of cross-module read composition.
 *
 * <h2>Ownership of writes</h2>
 * This module owns none of the three campaigns' lifecycle. Every mutating
 * action ({@link com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignActionType})
 * delegates straight to that campaign's own service --
 * {@code smartfill.SmartFillCampaignService}, {@code
 * rebookengine.RebookCampaignService}, or {@code
 * reactivationengine.ReactivationCampaignService} -- each of which already
 * enforces its own state-machine invariants (a no-op, not an error, on an
 * already-terminal campaign). Campaign Center only resolves which service to
 * call and re-validates {@code providerId} ownership first.
 *
 * <h2>Unified status mapping</h2>
 * {@link com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignStatus}
 * is the cross-type filter/display status; each campaign's own raw status
 * (its real enum name, e.g. {@code NOTIFYING}) is preserved alongside it in
 * every {@code CampaignDto} so nothing is lost in translation. {@code
 * FAILED} is not a status any of the three engines persist -- it is derived
 * (an EXPIRED Smart Fill campaign that never notified a single candidate) to
 * distinguish "we tried and nobody booked" from "we never managed to try"
 * without inventing a new persisted state that would need its own migration
 * and job-sweep awareness across three modules.
 *
 * <h2>Known, documented gaps (not invented data)</h2>
 * Rebook and Reactivation campaigns have no distinct "notified at"/"viewed
 * at" timestamp columns the way {@code smartfill.CandidateOffer} does -- a
 * Rebook campaign's own {@code status} is the only signal a nudge went out,
 * with no timestamp to show in a timeline; Reactivation's nudge, by
 * contrast, is sent at {@code createdAt} itself (see that module's own
 * package-info), so its timeline can show a real "notification sent" event.
 * Pause/resume is only exposed for Smart Fill (the one engine with a
 * meaningful "waiting between stages" state to pause); Rebook and
 * Reactivation only gained a minimal {@code cancelCampaign} command here --
 * see each module's own new doc comments. Campaign Center never fabricates
 * an event, a timestamp, or a status transition none of the three engines
 * actually recorded.
 *
 * <h2>Scale</h2>
 * List/stats/Smart Actions load one business's own campaign rows into
 * memory (bounded by {@code provider_id}, never all campaigns platform-wide)
 * and filter/sort/paginate there -- the same discipline {@code
 * providerinsights.BusinessAnalyticsService#customersList} already uses for
 * an unbounded-in-advance per-provider collection. See V56's migration
 * comment for the provider-scoped indexes this relies on.
 */
package com.zairo.factory.campaigncenter;
