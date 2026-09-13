package com.zairo.factory.campaigncenter;

import com.zairo.factory.revenueengine.DecisionTrigger;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Campaign Center's own response shapes -- every field is composed live
 * from Smart Fill/Rebook/Reactivation/Revenue Engine/Customer Intelligence
 * data (see {@link CampaignCenterService}), never a guessed or hardcoded
 * value. Enum fields carry no server-rendered copy -- same "client owns the
 * localized text for a type" convention {@code
 * providerinsights.BusinessAnalyticsDtos.ActionItemType} already uses.
 */
public final class CampaignCenterDtos {

    private CampaignCenterDtos() {
    }

    /** Cross-type filter/display status. Each {@link CampaignDto} also carries the underlying engine's own raw status (see {@link CampaignDto#rawStatus}). */
    public enum CampaignStatus {
        /** Still trying to recover -- CREATED/SEARCHING/NOTIFYING (Smart Fill), CREATED/OFFERED (Rebook), SENT (Reactivation). */
        ACTIVE,
        /** Smart Fill only today -- notification staging paused by the owner. */
        PAUSED,
        /** The slot/customer was recovered -- terminal, success. */
        COMPLETED,
        /** The follow-up window closed with no recovery, after at least one real attempt to notify someone -- terminal. */
        EXPIRED,
        /** Derived, not a persisted engine status: expired having never notified a single candidate -- see this module's package-info. */
        FAILED,
        /** The owner cancelled the campaign -- terminal. */
        CANCELLED,
    }

    /** Whether the Decision Engine's own outcome ledger has resolved this campaign as a real win. */
    public enum CampaignOutcome {
        /** Still active -- the ledger hasn't resolved yet. */
        PENDING,
        RECOVERED,
        NOT_RECOVERED,
    }

    /** Never invented -- only set when a real, derivable condition explains why a campaign amounted to nothing. */
    public enum CampaignFailureReason {
        /** No eligible candidate was ever found/notified for this freed slot (Smart Fill only). */
        NO_CANDIDATES_NOTIFIED,
    }

    /**
     * A command the backend can actually execute right now for this exact
     * campaign -- computed server-side from real state, never a client
     * guess. The UI must only offer a button for an action present in
     * {@link CampaignDto#availableActions()} (see this module's own
     * package-info -- "no fake buttons").
     */
    public enum CampaignActionType {
        /** Smart Fill only, only while NOTIFYING. */
        PAUSE,
        /** Smart Fill only, only while PAUSED. */
        RESUME,
        /** Any type, while the campaign is still active/paused. */
        CANCEL,
        /** Smart Fill only -- an EXPIRED, never-recovered campaign whose slot is still open. */
        RETRY,
    }

    /** A purely informational "what's this campaign waiting on" hint -- distinct from {@link CampaignActionType}, which is a real button. */
    public enum CampaignNextAction {
        NONE,
        WAITING_FOR_RESPONSE,
        PAUSED_BY_OWNER,
        RETRY_AVAILABLE,
        VIEW_RECOVERED_BOOKING,
    }

    @Schema(description = "One campaign, of any of the three engine types, in a single shared shape. Fields "
            + "that don't apply to a given type (e.g. slotStartsAt for Rebook/Reactivation, which target a "
            + "customer rather than a fixed slot) are null rather than a placeholder value.")
    public record CampaignDto(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            CampaignType type,
            CampaignStatus status,
            @Schema(description = "The owning engine's own raw status name, e.g. \"NOTIFYING\".") String rawStatus,
            DecisionTrigger triggerReason,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            UUID serviceId,
            String serviceTitle,
            @Schema(description = "Smart Fill only -- the slot's assigned staff member, if any.") UUID employeeId,
            String employeeName,
            @Schema(description = "The targeted/winning customer. Rebook and Reactivation always target one "
                    + "customer; Smart Fill is null until a candidate actually accepts.") UUID customerId,
            @Schema(description = "Smart Fill only -- Rebook/Reactivation target a customer's next visit, not a fixed slot.")
            Instant slotStartsAt,
            Instant slotEndsAt,
            @Schema(description = "How many candidates were found/targeted. 1 for Rebook/Reactivation (single-customer campaigns).")
            int candidateCount,
            int notifiedCount,
            int viewedCount,
            int acceptedCount,
            UUID recoveredBookingId,
            @Schema(description = "From the Decision Engine's own outcome ledger -- null while PENDING.") BigDecimal recoveredRevenue,
            String currency,
            Instant createdAt,
            @Schema(description = "Derived last-known-activity timestamp (latest of creation/notification/response/completion) -- not a stored column.")
            Instant updatedAt,
            Instant completedAt,
            CampaignOutcome outcome,
            CampaignFailureReason failureReason,
            CampaignNextAction nextAction,
            List<CampaignActionType> availableActions) {
    }

    public record CampaignListFilter(
            CampaignType type,
            CampaignStatus status,
            UUID serviceId,
            UUID employeeId,
            Instant from,
            Instant to,
            String search,
            int page,
            int pageSize,
            boolean newestFirst) {
    }

    public record CampaignListResponse(List<CampaignDto> items, int page, int pageSize, long totalItems, int totalPages) {
    }

    public enum CampaignTimelineEventType {
        CAMPAIGN_CREATED,
        CANDIDATES_SELECTED,
        NOTIFICATION_SENT,
        OFFER_ACCEPTED,
        BOOKING_CREATED,
        SLOT_RECOVERED,
        CAMPAIGN_EXPIRED,
        CAMPAIGN_CANCELLED,
        CAMPAIGN_COMPLETED,
    }

    @Schema(description = "relatedUserId is the candidate this event is about, when applicable (e.g. NOTIFICATION_SENT) -- null for campaign-level events.")
    public record CampaignTimelineEvent(CampaignTimelineEventType type, Instant occurredAt, UUID relatedUserId) {
    }

    @Schema(description = "Built only from real, stored timestamps -- see this module's package-info for the "
            + "documented gaps (Rebook has no distinct notified-at timestamp, so it never appears here; "
            + "pause/resume aren't timestamped anywhere, so they never appear here either).")
    public record CampaignTimelineResponse(UUID providerId, CampaignType type, UUID campaignId, List<CampaignTimelineEvent> events) {
    }

    public record CampaignStatsResponse(
            UUID providerId,
            @Schema(description = "ACTIVE + PAUSED.") long activeCampaigns,
            long completedCampaigns,
            long failedCampaigns,
            long expiredCampaigns,
            long cancelledCampaigns,
            @Schema(description = "= completedCampaigns -- every COMPLETED campaign is, by definition, a recovered slot/customer.")
            long recoveredSlots,
            @Schema(description = "Sum of recoveredRevenue over every campaign the outcome ledger marked RECOVERED.")
            BigDecimal totalRecoveredRevenue,
            String currency,
            @Schema(description = "recoveredSlots / total campaigns ever run for this provider -- 0 if none yet.")
            double conversionRate,
            long notificationsSent,
            long offersAccepted,
            @Schema(description = "Average minutes from createdAt to completedAt over every completed/expired/cancelled campaign -- null if none have completed yet.")
            Double averageCompletionMinutes,
            @Schema(description = "= the Smart Action Center's own item count for this provider right now.")
            long campaignsRequiringAttention) {
    }

    public enum SmartActionType {
        /** A Smart Fill campaign still notifying whose slot starts within the next 2 hours, unbooked. */
        CAMPAIGN_EXPIRING_SOON,
        /** An expired Smart Fill campaign, slot still open, that never notified a single candidate. */
        FAILED_CAMPAIGN,
        /** An expired Smart Fill campaign, slot still open, that did notify candidates but none booked -- safe to retry. */
        RETRIABLE_CAMPAIGN,
        /** Customer Intelligence: DUE_FOR_REBOOKING. */
        REBOOKING_OPPORTUNITY,
        /** Customer Intelligence: AT_RISK. */
        AT_RISK_CUSTOMER,
        /** Customer Intelligence: INACTIVE. */
        LONG_INACTIVE_CUSTOMER,
    }

    public enum SmartActionPriority {
        HIGH,
        MEDIUM,
        LOW,
    }

    @Schema(description = "One actionable signal, always naming exactly the real campaign/customer/service/"
            + "employee it's about. recommendedActions is a subset of CampaignActionType this item's own "
            + "campaign genuinely supports right now -- empty for customer-level signals, since no backend "
            + "command exists yet for 'nudge this customer now' beyond what Rebook/Reactivation's own jobs "
            + "already do automatically.")
    public record SmartActionItem(
            SmartActionType type,
            SmartActionPriority priority,
            UUID providerId,
            CampaignType campaignType,
            UUID campaignId,
            UUID customerId,
            UUID serviceId,
            UUID employeeId,
            UUID bookingId,
            @Schema(description = "The timestamp that made this actionable -- a slot's start time, a customer's last visit, etc.")
            Instant relatedAt,
            @Schema(description = "When this item was computed -- Smart Actions is current state, not a historical report.")
            Instant observedAt,
            List<CampaignActionType> recommendedActions) {
    }

    public record SmartActionsResponse(UUID providerId, List<SmartActionItem> items) {
    }
}
