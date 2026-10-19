package com.zairo.factory.platforminsights;

import com.zairo.factory.platformadmin.AnyPlatformRole;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformReport;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformTrends;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Read-only — any authenticated platform role (PLATFORM_ADMIN or PLATFORM_SUPPORT). */
@RestController
@Tag(name = "Platform Admin — Dashboard")
public class PlatformInsightsController {

    private final PlatformInsightsService platformInsightsService;

    public PlatformInsightsController(PlatformInsightsService platformInsightsService) {
        this.platformInsightsService = platformInsightsService;
    }

    @Operation(summary = "Platform dashboard v1", description = """
            Users/Businesses/Subscriptions/Bookings/Payments/Revenue-MRR — every number is a live query, \
            nothing stored or cached. Deliberately doesn't include growth funnel, DAU/WAU/MAU, or system \
            health — those need a new event-tracking model that doesn't exist yet (see \
            docs/PRODUCT_PRODUCTION_ROADMAP.md section 9/10).""")
    @ApiResponse(responseCode = "200", description = "Dashboard metrics")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/dashboard")
    @AnyPlatformRole
    public PlatformDashboardMetrics dashboard() {
        return platformInsightsService.dashboardMetrics();
    }

    @Operation(summary = "Platform dashboard trends", description = """
            Bookings created per UTC day for the last N days (default 14, capped at 31), oldest first, \
            zero-filled — the data behind the dashboard's sparklines.""")
    @ApiResponse(responseCode = "200", description = "Daily series")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/dashboard/trends")
    @AnyPlatformRole
    public PlatformTrends trends(@RequestParam(defaultValue = "14") int days) {
        return platformInsightsService.trends(days);
    }

    @Operation(summary = "Platform report", description = """
            History for the reports screen over the last N days (default 30, capped at 90): bookings created, \
            marketplace commission and subscription revenue per UTC day (zero-filled, oldest first), and the \
            window's bookings by status.""")
    @ApiResponse(responseCode = "200", description = "Report data")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/reports")
    @AnyPlatformRole
    public PlatformReport report(@RequestParam(defaultValue = "30") int days) {
        return platformInsightsService.report(days);
    }
}
