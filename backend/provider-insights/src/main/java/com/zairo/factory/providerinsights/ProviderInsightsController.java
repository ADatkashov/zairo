package com.zairo.factory.providerinsights;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.CustomerSummary;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.DashboardMetrics;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.revenueengine.RevenueAttributionService;
import com.zairo.factory.revenueengine.RevenueEngineDtos.RevenueSummaryResponse;
import com.zairo.factory.smartfill.SmartFillAnalyticsService;
import com.zairo.factory.smartfill.SmartFillDtos.SmartFillPerformanceResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Provider Insights")
public class ProviderInsightsController {

    private final ProviderInsightsService providerInsightsService;
    private final ProviderOwnership providerOwnership;
    private final SmartFillAnalyticsService smartFillAnalyticsService;
    private final RevenueAttributionService revenueAttributionService;

    public ProviderInsightsController(ProviderInsightsService providerInsightsService,
            ProviderOwnership providerOwnership, SmartFillAnalyticsService smartFillAnalyticsService,
            RevenueAttributionService revenueAttributionService) {
        this.providerInsightsService = providerInsightsService;
        this.providerOwnership = providerOwnership;
        this.smartFillAnalyticsService = smartFillAnalyticsService;
        this.revenueAttributionService = revenueAttributionService;
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
    public List<CustomerSummary> customerHistory(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
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
    public DashboardMetrics dashboardMetrics(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
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
    public SmartFillPerformanceResponse smartFillPerformance(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
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
    public RevenueSummaryResponse revenueSummary(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        return revenueAttributionService.summary(providerId);
    }
}
