package com.zairo.factory.subscriptions;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.subscriptions.SubscriptionDtos.SubscriptionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Subscriptions")
public class SubscriptionController {

    private final SubscriptionService subscriptionService;

    public SubscriptionController(SubscriptionService subscriptionService) {
        this.subscriptionService = subscriptionService;
    }

    @Operation(summary = "Get my subscription", description = "Always returns something — a subscription is "
            + "created lazily (FREE, ACTIVE) the first time this is called for a given owner.")
    @ApiResponse(responseCode = "200", description = "The caller's own subscription")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/subscriptions/me")
    public SubscriptionResponse getMine(HttpServletRequest httpRequest) {
        UUID ownerUserId = CurrentUser.requireUserId(httpRequest);
        return SubscriptionResponse.from(subscriptionService.getOrCreate(ownerUserId));
    }

    @Operation(summary = "Upgrade to PRO", description = "Charges the PRO monthly price immediately through the "
            + "(mock, local-dev) payment provider and starts a fresh full-price billing period right away — no "
            + "proration. Already PRO: undoes a pending downgrade instead of charging again.")
    @ApiResponse(responseCode = "200", description = "Now on the PRO plan")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "402", description = "The payment was declined or the payment provider errored.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/subscriptions/upgrade")
    public SubscriptionResponse upgrade(HttpServletRequest httpRequest) {
        UUID ownerUserId = CurrentUser.requireUserId(httpRequest);
        return SubscriptionResponse.from(subscriptionService.upgradeToPro(ownerUserId));
    }

    @Operation(summary = "Downgrade to FREE", description = "Self-service, takes effect at the end of the "
            + "current paid period — PRO access and limits continue until then, no refund of the period "
            + "already paid for. A FREE owner has nothing to downgrade from (no-op).")
    @ApiResponse(responseCode = "200", description = "Downgrade scheduled (or already FREE)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/subscriptions/downgrade")
    public SubscriptionResponse downgrade(HttpServletRequest httpRequest) {
        UUID ownerUserId = CurrentUser.requireUserId(httpRequest);
        return SubscriptionResponse.from(subscriptionService.downgradeToFreeAtPeriodEnd(ownerUserId));
    }
}
