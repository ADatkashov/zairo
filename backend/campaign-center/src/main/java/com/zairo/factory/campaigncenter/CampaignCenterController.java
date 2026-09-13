package com.zairo.factory.campaigncenter;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignActionType;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignDto;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignListFilter;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignListResponse;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignStatsResponse;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignStatus;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignTimelineResponse;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.SmartActionsResponse;
import com.zairo.factory.providers.ProviderOwnership;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Owner-only, following the exact {@code ProviderOwnership.requireOwner} +
 * {@code CurrentUser.requireUserId} pattern every other business-scoped
 * controller in this codebase uses -- {@code providerId} always comes from
 * the path and is re-validated against the authenticated caller on every
 * request, never trusted. Every action endpoint additionally re-validates
 * that the resolved campaign actually belongs to {@code providerId} inside
 * {@link CampaignCenterService} (defense in depth -- a campaign id under
 * the wrong provider 404s, it never leaks another business's campaign).
 */
@RestController
@Tag(name = "Campaign Center")
public class CampaignCenterController {

    private final CampaignCenterService campaignCenterService;
    private final ProviderOwnership providerOwnership;

    public CampaignCenterController(CampaignCenterService campaignCenterService, ProviderOwnership providerOwnership) {
        this.campaignCenterService = campaignCenterService;
        this.providerOwnership = providerOwnership;
    }

    @Operation(summary = "List this provider's campaigns", description = """
            Owner-only. Every Smart Fill/Rebook/Reactivation campaign this provider has ever run, in one \
            shared shape, newest-created first by default. Supports filtering by type, unified status, \
            service, staff member, a [from, to) creation-date window, and a free-text search over service \
            title/staff name -- and pagination.""")
    @ApiResponse(responseCode = "200", description = "A page of campaigns, empty if none match")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/campaigns")
    public CampaignListResponse list(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @RequestParam(required = false) CampaignType type,
            @RequestParam(required = false) CampaignStatus status,
            @RequestParam(required = false) UUID serviceId,
            @RequestParam(required = false) UUID employeeId,
            @Parameter(description = "Only campaigns created on/after this instant.")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @Parameter(description = "Only campaigns created before this instant.")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @Parameter(description = "Case-insensitive substring match over service title or staff name.")
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(defaultValue = "true") boolean newestFirst,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return campaignCenterService.list(providerId,
                new CampaignListFilter(type, status, serviceId, employeeId, from, to, search, page, pageSize, newestFirst));
    }

    @Operation(summary = "Campaign Center -- aggregate statistics", description = """
            Owner-only. Active/completed/failed/expired/cancelled campaign counts, recovered slots and \
            revenue (from the Decision Engine's own outcome ledger), conversion rate, notifications sent, \
            offers accepted, average completion time, and how many campaigns the Smart Action Center \
            currently flags for this provider. Computed fresh on every call, not a persisted aggregate.""")
    @ApiResponse(responseCode = "200", description = "Aggregate statistics, all-zero if this provider has no campaigns yet")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/campaigns/stats")
    public CampaignStatsResponse stats(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return campaignCenterService.stats(providerId);
    }

    @Operation(summary = "Smart Action Center", description = """
            Owner-only. Deterministic, rule-based actionable items -- Smart Fill campaigns expiring soon, \
            expired campaigns with a safe retry available, and Customer Intelligence's due-for-rebooking/ \
            at-risk/long-inactive customers -- never a generated recommendation. Not date-scoped: current \
            state, not a historical report.""")
    @ApiResponse(responseCode = "200", description = "Action items, priority-ordered, empty if nothing currently needs attention")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/smart-actions")
    public SmartActionsResponse smartActions(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return campaignCenterService.smartActions(providerId);
    }

    @Operation(summary = "Campaign detail", description = "Owner-only. One campaign's full detail, in the same shape as the list.")
    @ApiResponse(responseCode = "200", description = "Campaign detail")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "Provider or campaign not found, or the campaign belongs to another provider")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/campaigns/{type}/{campaignId}")
    public CampaignDto detail(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @PathVariable CampaignType type, @PathVariable UUID campaignId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return campaignCenterService.detail(providerId, type, campaignId);
    }

    @Operation(summary = "Campaign timeline", description = """
            Owner-only. This campaign's real lifecycle events, built only from stored timestamps -- never a \
            fabricated event (see the Campaign Center module's own doc comment for the documented gaps: \
            Rebook has no distinct notification-sent timestamp; pause/resume aren't timestamped anywhere).""")
    @ApiResponse(responseCode = "200", description = "Timeline events, oldest first")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "Provider or campaign not found, or the campaign belongs to another provider")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/campaigns/{type}/{campaignId}/timeline")
    public CampaignTimelineResponse timeline(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @PathVariable CampaignType type, @PathVariable UUID campaignId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return campaignCenterService.timeline(providerId, type, campaignId);
    }

    @Operation(summary = "Pause a campaign", description = "Owner-only. Smart Fill only, only while a stage is actively out (NOTIFYING).")
    @ApiResponse(responseCode = "200", description = "Paused -- returns the refreshed campaign detail")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "Provider or campaign not found, or the campaign belongs to another provider")
    @ApiResponse(responseCode = "409", description = "The campaign isn't in a state this action applies to, or this type doesn't support it")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/campaigns/{type}/{campaignId}/pause")
    public CampaignDto pause(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @PathVariable CampaignType type, @PathVariable UUID campaignId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        campaignCenterService.executeAction(providerId, type, campaignId, CampaignActionType.PAUSE);
        return campaignCenterService.detail(providerId, type, campaignId);
    }

    @Operation(summary = "Resume a paused campaign", description = "Owner-only. Smart Fill only, only while PAUSED -- schedules the next stage as if it had just been sent.")
    @ApiResponse(responseCode = "200", description = "Resumed -- returns the refreshed campaign detail")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "Provider or campaign not found, or the campaign belongs to another provider")
    @ApiResponse(responseCode = "409", description = "The campaign isn't in a state this action applies to, or this type doesn't support it")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/campaigns/{type}/{campaignId}/resume")
    public CampaignDto resume(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @PathVariable CampaignType type, @PathVariable UUID campaignId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        campaignCenterService.executeAction(providerId, type, campaignId, CampaignActionType.RESUME);
        return campaignCenterService.detail(providerId, type, campaignId);
    }

    @Operation(summary = "Cancel a campaign", description = """
            Owner-only. Any type, any time the campaign is still active/paused -- an owner-initiated abort, \
            same close-out its own engine already uses for a normal expiry (every still-open offer closed \
            out, the outcome ledger resolved as not-recovered). A cancelled or already-completed campaign \
            can never be incorrectly restarted -- this is terminal.""")
    @ApiResponse(responseCode = "200", description = "Cancelled -- returns the refreshed campaign detail")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "Provider or campaign not found, or the campaign belongs to another provider")
    @ApiResponse(responseCode = "409", description = "The campaign is already terminal (completed/expired/cancelled)")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/campaigns/{type}/{campaignId}/cancel")
    public CampaignDto cancel(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @PathVariable CampaignType type, @PathVariable UUID campaignId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        campaignCenterService.executeAction(providerId, type, campaignId, CampaignActionType.CANCEL);
        return campaignCenterService.detail(providerId, type, campaignId);
    }

    @Operation(summary = "Retry a failed/expired campaign", description = """
            Owner-only. Smart Fill only -- only for a campaign that expired never having recovered its slot, \
            whose slot is still genuinely open. Re-runs the same candidate-discovery-and-first-stage flow the \
            original cancellation triggered, on the same campaign (continuing its own stage numbering) rather \
            than creating a duplicate campaign. Idempotent: calling this on an already-active campaign, or one \
            whose slot got booked meanwhile, is a no-op 409 rather than a duplicate notification round.""")
    @ApiResponse(responseCode = "200", description = "Retried -- returns the refreshed campaign detail")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", description = "Provider or campaign not found, or the campaign belongs to another provider")
    @ApiResponse(responseCode = "409", description = "Not retriable right now (not expired, already recovered, slot no longer open, or no eligible candidates), or this type doesn't support it")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/campaigns/{type}/{campaignId}/retry")
    public CampaignDto retry(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @PathVariable CampaignType type, @PathVariable UUID campaignId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        campaignCenterService.executeAction(providerId, type, campaignId, CampaignActionType.RETRY);
        return campaignCenterService.detail(providerId, type, campaignId);
    }
}
