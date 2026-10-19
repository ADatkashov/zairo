package com.zairo.factory.customerintelligence;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.customerintelligence.CustomerIntelligenceDtos.BusinessCustomerIntelligenceResponse;
import com.zairo.factory.customerintelligence.CustomerIntelligenceDtos.MyIntelligenceResponse;
import com.zairo.factory.providers.OwnsProvider;
import com.zairo.factory.providers.ProviderOwnership;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/**
 * The two read surfaces Customer Intelligence exposes over HTTP -- see this
 * module's own package-info for the third, internal one ({@code
 * CustomerIntelligenceService} itself, read directly by Revenue Engine
 * strategies with no HTTP hop). Both endpoints authorize off the
 * authenticated caller's own identity, never a body/query parameter: a
 * customer can only ever read their own profile, and a business owner can
 * only ever read customers of a business they actually own -- see {@link
 * ProviderOwnership#requireOwner}.
 */
@RestController
@Tag(name = "Customer Intelligence")
public class CustomerIntelligenceController {

    private final CustomerIntelligenceService service;
    private final ProviderOwnership providerOwnership;

    public CustomerIntelligenceController(CustomerIntelligenceService service, ProviderOwnership providerOwnership) {
        this.service = service;
        this.providerOwnership = providerOwnership;
    }

    @Operation(summary = "My own customer intelligence", description = """
            The caller's own platform-wide behaviour profile -- completed bookings, last/next expected visit, \
            preferences, favourite business/service, retention status. Calculated on first read if this is the \
            caller's first time being asked about, cached afterwards until their next booking event. Never \
            exposes the internal customer-value score (see this module's own package-info) -- that is \
            business-facing intelligence, not something shown back to the customer.""")
    @ApiResponse(responseCode = "200", description = "The caller's own intelligence profile")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/me/customer-intelligence")
    public MyIntelligenceResponse myIntelligence() {
        UUID userId = CurrentUser.requireUserId();
        return MyIntelligenceResponse.from(service.getOrCalculateProfile(userId));
    }

    @Operation(summary = "A customer's intelligence for this business", description = """
            Owner-only. This customer's relationship with this specific business only -- visit history, \
            spend, favourite employee/service, visit cadence, attendance/cancellation rates, relationship \
            value score, and retention status. Never includes data from any other business this customer \
            has ever booked with.""")
    @ApiResponse(responseCode = "200", description = "The customer's intelligence for this business (a fresh, all-empty profile if they have never booked here)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/customers/{userId}/intelligence")
    @OwnsProvider
    public BusinessCustomerIntelligenceResponse businessCustomerIntelligence(
            @Parameter(description = "The business's id.") @PathVariable UUID providerId,
            @Parameter(description = "The customer's id.") @PathVariable UUID userId) {
        return BusinessCustomerIntelligenceResponse.from(service.getOrCalculateProviderProfile(userId, providerId));
    }
}
