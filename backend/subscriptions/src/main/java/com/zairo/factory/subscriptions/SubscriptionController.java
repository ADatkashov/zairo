package com.zairo.factory.subscriptions;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.subscriptions.SubscriptionDtos.SubscriptionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Subscriptions")
public class SubscriptionController {

    private final SubscriptionService subscriptionService;
    private final SubscriptionRenewalService subscriptionRenewalService;

    public SubscriptionController(SubscriptionService subscriptionService,
            SubscriptionRenewalService subscriptionRenewalService) {
        this.subscriptionService = subscriptionService;
        this.subscriptionRenewalService = subscriptionRenewalService;
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
        SubscriptionService.SubscriptionUpgradeResult result = subscriptionService.upgradeToPro(ownerUserId);
        return SubscriptionResponse.from(result.subscription(), result.checkoutUrl());
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

    @Operation(summary = "Retry a past-due charge now", description = "The Billing screen's grace-period "
            + "banner's \"Fix\" action — attempts the same renewal charge the daily sweep would eventually retry, "
            + "immediately instead of waiting. Only valid while the subscription is PAST_DUE.")
    @ApiResponse(responseCode = "200", description = "Retried — check the returned status: ACTIVE if it "
            + "succeeded, still PAST_DUE if it failed again.")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", description = "No subscription for this owner.")
    @ApiResponse(responseCode = "409", description = "Subscription is not past due.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/subscriptions/retry-charge")
    public SubscriptionResponse retryCharge(HttpServletRequest httpRequest) {
        UUID ownerUserId = CurrentUser.requireUserId(httpRequest);
        return SubscriptionResponse.from(subscriptionRenewalService.retryPastDueCharge(ownerUserId));
    }

    @Operation(summary = "List my subscription charges", description = "The Billing screen's invoice history "
            + "(v2 design audit) — every upgrade/renewal charge attempt for the caller's subscription, most "
            + "recent first. Not paginated: an owner accrues at most one row per billing period.")
    @ApiResponse(responseCode = "200", description = "The caller's charge history (possibly empty)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/subscriptions/me/charges")
    public List<SubscriptionDtos.SubscriptionChargeResponse> listCharges(HttpServletRequest httpRequest) {
        UUID ownerUserId = CurrentUser.requireUserId(httpRequest);
        return subscriptionService.listCharges(ownerUserId).stream()
                .map(SubscriptionDtos.SubscriptionChargeResponse::from).toList();
    }
}
