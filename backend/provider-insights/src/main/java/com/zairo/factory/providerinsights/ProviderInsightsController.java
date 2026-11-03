package com.zairo.factory.providerinsights;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.customerintelligence.RetentionStatus;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.ActionCenterResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.BookingAnalyticsResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.CustomerAnalyticsResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.CustomerListItem;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.OverviewResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.RevenueAnalyticsResponse;
import com.zairo.factory.providerinsights.BusinessBackupDtos.BackupResponse;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.CustomerSummary;
import com.zairo.factory.platformadmin.AnyPlatformRole;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.DashboardMetrics;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.PlatformBusinessOverview;
import com.zairo.factory.providers.OwnsProvider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.revenueengine.RevenueAttributionService;
import com.zairo.factory.revenueengine.RevenueEngineDtos.RevenueSummaryResponse;
import com.zairo.factory.smartfill.SmartFillAnalyticsService;
import com.zairo.factory.smartfill.SmartFillDtos.CampaignSummary;
import com.zairo.factory.smartfill.SmartFillDtos.SmartFillPerformanceResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Provider Insights")
public class ProviderInsightsController {

    private final ProviderInsightsService providerInsightsService;
    private final ProviderOwnership providerOwnership;
    private final SmartFillAnalyticsService smartFillAnalyticsService;
    private final RevenueAttributionService revenueAttributionService;
    private final BusinessAnalyticsService businessAnalyticsService;
    private final BusinessBackupService businessBackupService;

    public ProviderInsightsController(ProviderInsightsService providerInsightsService,
            ProviderOwnership providerOwnership, SmartFillAnalyticsService smartFillAnalyticsService,
            RevenueAttributionService revenueAttributionService, BusinessAnalyticsService businessAnalyticsService,
            BusinessBackupService businessBackupService) {
        this.providerInsightsService = providerInsightsService;
        this.providerOwnership = providerOwnership;
        this.smartFillAnalyticsService = smartFillAnalyticsService;
        this.revenueAttributionService = revenueAttributionService;
        this.businessAnalyticsService = businessAnalyticsService;
        this.businessBackupService = businessBackupService;
    }

    @Operation(summary = "A business's overview for moderators", description = """
            Any platform role. Who owns the business and how to reach them, how many services it has listed and how \
            many bookings it has taken — what a moderator needs to approve or suspend it without leaving the console.""")
    @ApiResponse(responseCode = "200", description = "The overview")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/businesses/{providerId}/overview")
    @AnyPlatformRole
    public PlatformBusinessOverview platformOverview(@PathVariable UUID providerId) {
        return providerInsightsService.platformOverview(providerId);
    }

    @Operation(summary = "This provider's customer history", description = """
            Owner-only. Every distinct customer who has ever booked with this provider, newest-visited \
            first — total/completed booking counts, lifetime spend (from SUCCEEDED payments only), last \
            visit, and their most-booked service. Computed fresh from Booking/Payment on every call, not \
            a separate CRM table (see the module's own doc comment).""")
    @ApiResponse(responseCode = "200", description = "Customer summaries, empty list if this provider has no bookings yet")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/customers")
    @OwnsProvider
    public List<CustomerSummary> customerHistory(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return providerInsightsService.customerHistory(providerId);
    }

    @Operation(summary = "This provider's dashboard metrics", description = """
            Owner-only. Booking mix (total/completed/cancelled, cancellation rate), distinct customer \
            count, revenue and average check (from SUCCEEDED payments only), and the top 5 services by \
            booking count. Computed fresh on every call, same as customer history.""")
    @ApiResponse(responseCode = "200", description = "Dashboard metrics, all-zero if this provider has no bookings yet")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/dashboard")
    @OwnsProvider
    public DashboardMetrics dashboardMetrics(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return providerInsightsService.dashboardMetrics(providerId);
    }

    @Operation(summary = "This provider's Smart Fill performance", description = """
            Owner-only. How many cancelled bookings' freed slots Smart Fill found candidates for, how many \
            customers were notified/viewed an offer, how many slots were actually refilled, the resulting \
            recovery rate, and the revenue those refilled slots represent -- computed fresh from this \
            provider's own campaigns/offers, same as the other Smart Fill endpoints have no separate \
            aggregates table.""")
    @ApiResponse(responseCode = "200", description = "Smart Fill performance, all-zero if this provider has no cancellations yet")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/smart-fill/performance")
    @OwnsProvider
    public SmartFillPerformanceResponse smartFillPerformance(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return smartFillAnalyticsService.performance(providerId);
    }

    @Operation(summary = "Revenue Recovered by ZAIRO", description = """
            Owner-only. The Decision Engine's own outcome ledger for this provider: total revenue recovered \
            across every strategy the engine has ever executed (Smart Fill today, more strategies later -- \
            see revenue-engine's package-info), how many decisions it made, how many actually paid off, and \
            the breakdown by action type. This is the top-line "how much has ZAIRO made you" number.""")
    @ApiResponse(responseCode = "200", description = "Revenue summary, all-zero if no decisions have been made for this provider yet")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/revenue-engine/summary")
    @OwnsProvider
    public RevenueSummaryResponse revenueSummary(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return revenueAttributionService.summary(providerId);
    }

    @Operation(summary = "Business Intelligence Dashboard — overview", description = """
            Owner-only. The dashboard's top-line snapshot for one reporting period: booking mix, revenue \
            (from SUCCEEDED payments only), utilization (booked vs. offered availability-slot duration — \
            null if this provider has no slots in range, never a guessed figure), lifetime returning-customer \
            rate, and revenue recovered by the Decision Engine within the period. [from]/[to] default to the \
            current calendar month (UTC) through now when omitted.""")
    @ApiResponse(responseCode = "200", description = "Overview metrics for the resolved [from, to) range")
    @ApiResponse(responseCode = "400", description = "'from' is not before 'to'")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/overview")
    @OwnsProvider
    public OverviewResponse analyticsOverview(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Start of the reporting period, inclusive. Defaults to the start of the "
                    + "current UTC calendar month.")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @Parameter(description = "End of the reporting period, exclusive. Defaults to now.")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return businessAnalyticsService.overview(providerId, from, to);
    }

    @Operation(summary = "Business Intelligence Dashboard — revenue", description = """
            Owner-only. Total/average revenue for the period (SUCCEEDED payments only), a daily revenue \
            trend, breakdowns by service and by staff member, and revenue recovered by the Decision Engine \
            within the same period.""")
    @ApiResponse(responseCode = "200", description = "Revenue analytics for the resolved [from, to) range")
    @ApiResponse(responseCode = "400", description = "'from' is not before 'to'")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/revenue")
    @OwnsProvider
    public RevenueAnalyticsResponse analyticsRevenue(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return businessAnalyticsService.revenue(providerId, from, to);
    }

    @Operation(summary = "Business Intelligence Dashboard — bookings", description = """
            Owner-only. Booking mix (completed/upcoming/cancelled/no-show), cancellation/no-show/repeat-booking \
            rates, and a daily booking trend, all scoped to bookings whose slot falls within the period.""")
    @ApiResponse(responseCode = "200", description = "Booking analytics for the resolved [from, to) range")
    @ApiResponse(responseCode = "400", description = "'from' is not before 'to'")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/bookings")
    @OwnsProvider
    public BookingAnalyticsResponse analyticsBookings(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return businessAnalyticsService.bookings(providerId, from, to);
    }

    @Operation(summary = "Business Intelligence Dashboard — Smart Fill", description = """
            Owner-only. The same Smart Fill performance snapshot as {@code /smart-fill/performance}, scoped \
            to campaigns created within the given reporting period instead of this provider's whole history \
            — so it moves with the dashboard's selected date range.""")
    @ApiResponse(responseCode = "200", description = "Smart Fill performance for the resolved [from, to) range")
    @ApiResponse(responseCode = "400", description = "'from' is not before 'to'")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/smart-fill")
    @OwnsProvider
    public SmartFillPerformanceResponse analyticsSmartFill(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return businessAnalyticsService.smartFillPerformance(providerId, from, to);
    }

    @Operation(summary = "Business Intelligence Dashboard — customers", description = """
            Owner-only. Business-level rollup over Customer Intelligence's per-customer profiles for this \
            provider: retention mix (active/due-for-rebooking/at-risk/inactive), average visit interval and \
            customer value, and favourite services/staff. Most fields are lifetime (a customer relationship \
            spans the whole history); [from]/[to] only scope "new customers" (first visit within the period).""")
    @ApiResponse(responseCode = "200", description = "Customer analytics, all-zero if this provider has no customers yet")
    @ApiResponse(responseCode = "400", description = "'from' is not before 'to'")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/customers")
    @OwnsProvider
    public CustomerAnalyticsResponse analyticsCustomers(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return businessAnalyticsService.customers(providerId, from, to);
    }

    @Operation(summary = "Business Intelligence Dashboard — Action Center", description = """
            Owner-only. Deterministic, rule-based signals for what deserves attention right now — active \
            Smart Fill opportunities, customers due for rebooking, customers at retention risk, and near-term \
            low-utilization days — never a generated recommendation. Not date-scoped: this reflects current \
            state, not a historical report.""")
    @ApiResponse(responseCode = "200", description = "Action items, empty if nothing currently needs attention")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/actions")
    @OwnsProvider
    public ActionCenterResponse analyticsActions(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return businessAnalyticsService.actions(providerId);
    }

    @Operation(summary = "Active Smart Fill campaigns", description = """
            Owner-only. Every campaign still actively trying to recover a freed slot (not yet BOOKED/EXPIRED/ \
            CANCELLED) -- the Action Center's Smart Fill opportunity drill-down. Not date-scoped: current \
            state, not a historical report.""")
    @ApiResponse(responseCode = "200", description = "Active campaigns, oldest slot first; empty if none")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/smart-fill/active")
    @OwnsProvider
    public List<CampaignSummary> analyticsActiveSmartFillCampaigns(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        return smartFillAnalyticsService.activeCampaigns(providerId);
    }

    @Operation(summary = "Business Intelligence Dashboard — customer list", description = """
            Owner-only. The individual customers behind one of the customer-analytics counts -- the Action \
            Center's rebook-opportunity/retention-risk drill-down. Optionally filtered by retention status; \
            unfiltered returns every customer who has ever had a relationship with this provider. Not \
            date-scoped: current relationship state, not a historical report.""")
    @ApiResponse(responseCode = "200", description = "Matching customers, empty if none")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/analytics/customers/list")
    @OwnsProvider
    public List<CustomerListItem> analyticsCustomersList(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Only customers currently in this retention state. Omit for every customer.")
            @RequestParam(required = false) RetentionStatus retentionStatus) {
        return businessAnalyticsService.customersList(providerId, retentionStatus);
    }

    @Operation(summary = "A copy of the business's schedule, customers and services", description = """
            Owner-only. Everything needed to keep working without the app: bookings in the window with the \
            customer's name and contact and the person (master) booked, the customer book, and the service price \
            list. Contains customers' personal details. `from`/`to` default to the last 30 and next 180 days; the \
            window may span at most 400 days.""")
    @ApiResponse(responseCode = "200", description = "The copy")
    @ApiResponse(responseCode = "400", ref = "BadRequest", description = "`from` is not before `to`, or the window "
            + "is longer than 400 days.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/backup")
    @OwnsProvider
    public BackupResponse backup(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Parameter(description = "Window start, inclusive (ISO-8601 instant).") @RequestParam(required = false) Instant from,
            @Parameter(description = "Window end, exclusive (ISO-8601 instant).") @RequestParam(required = false) Instant to) {
        return businessBackupService.backup(providerId, from, to);
    }
}
