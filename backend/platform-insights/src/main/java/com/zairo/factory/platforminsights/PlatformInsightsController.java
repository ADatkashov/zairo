package com.zairo.factory.platforminsights;

import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
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
    public PlatformDashboardMetrics dashboard(HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAnyRole(httpRequest);
        return platformInsightsService.dashboardMetrics();
    }
}
