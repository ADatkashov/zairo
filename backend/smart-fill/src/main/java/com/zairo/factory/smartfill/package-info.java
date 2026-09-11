/**
 * Smart Fill Engine: when a booking is cancelled, automatically finds the
 * customers most likely to want the freed slot, scores and ranks them, and
 * offers it in small staged batches instead of one all-at-once blast --
 * stopping the instant someone books it.
 *
 * <p>Deliberately split into narrow collaborators instead of one large
 * service, each independently replaceable:
 * <ul>
 *   <li>{@link com.zairo.factory.smartfill.CandidateFinder} -- builds the
 *   candidate pool for a campaign (who's eligible at all) and computes each
 *   candidate's raw {@link com.zairo.factory.smartfill.CandidateSignals}.
 *   <li>{@link com.zairo.factory.smartfill.CandidateScorer} -- turns signals
 *   into a score. {@link com.zairo.factory.smartfill.RuleBasedCandidateScorer}
 *   is the only implementation today (configurable weights, see {@link
 *   com.zairo.factory.smartfill.SmartFillProperties.Scoring}); a future
 *   ML-based scorer is a second {@code @Component} implementing the same
 *   interface, swapped in by {@code @Primary}/a profile -- nothing else in
 *   this module needs to change.
 *   <li>{@link com.zairo.factory.smartfill.NotificationPolicy} -- anti-spam:
 *   whether a specific user may be offered anything from a specific
 *   provider right now.
 *   <li>{@link com.zairo.factory.smartfill.SmartFillCampaignService} --
 *   orchestrates the campaign lifecycle (start, advance a stage, close on a
 *   booking, expire) using the collaborators above; the only class that
 *   writes to {@link com.zairo.factory.smartfill.SmartFillCampaign}/{@link
 *   com.zairo.factory.smartfill.CandidateOffer}.
 *   <li>{@link com.zairo.factory.smartfill.SmartFillCampaignJob} -- the
 *   time-triggered side (advance a due stage, expire a stale campaign),
 *   same {@code @Scheduled} sweep pattern as {@code booking
 *   .BookingPaymentTimeoutJob} (see ADR-0005).
 * </ul>
 *
 * <p>Deliberately not built here (see the task this module was built from,
 * and CandidateScorer's own doc comment for exactly where each one plugs
 * in): ML-based scoring, per-user personalized ranking beyond the rule-based
 * signals already computed, dynamic discounts, predicted-cancellation
 * modeling, best-time recommendations, automatic rebooking, and broader
 * customer-retention campaigns unrelated to a specific freed slot -- every
 * one of those is a new {@code CandidateScorer}/{@code NotificationPolicy}
 * implementation or a new campaign trigger against the same {@link
 * com.zairo.factory.smartfill.SmartFillCampaign}/{@link
 * com.zairo.factory.smartfill.CandidateOffer} shape, not a rewrite.
 */
package com.zairo.factory.smartfill;
