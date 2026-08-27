package com.zairo.factory.providerinsights;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.CustomerSummary;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.DashboardMetrics;
import com.zairo.factory.providers.ProviderOwnership;
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

    public ProviderInsightsController(ProviderInsightsService providerInsightsService,
            ProviderOwnership providerOwnership) {
        this.providerInsightsService = providerInsightsService;
        this.providerOwnership = providerOwnership;
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
}
