package com.zairo.factory.subscriptions;

import com.zairo.factory.platformadmin.AnyPlatformRole;
import com.zairo.factory.platformadmin.PlatformAdminOnly;
import com.zairo.factory.platformadmin.PlatformAdminService;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import com.zairo.factory.subscriptions.SubscriptionDtos.SetSubscriptionPriceRequest;
import com.zairo.factory.subscriptions.SubscriptionDtos.SubscriptionPriceResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * The monthly price of PRO, set by PLATFORM_ADMIN instead of living in code. Any platform role may read it; only
 * PLATFORM_ADMIN may change it, and every change is audit-logged. A new price applies to charges made afterwards.
 */
@RestController
@Tag(name = "Platform Admin — Subscription price")
public class SubscriptionPriceAdminController {

    private final SubscriptionPricing pricing;
    private final PlatformAdminService platformAdminService;

    public SubscriptionPriceAdminController(SubscriptionPricing pricing, PlatformAdminService platformAdminService) {
        this.pricing = pricing;
        this.platformAdminService = platformAdminService;
    }

    @Operation(summary = "The monthly price of PRO", description = "What owners are charged (and shown) per month.")
    @ApiResponse(responseCode = "200", description = "Current price")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/subscription-price")
    @AnyPlatformRole
    public SubscriptionPriceResponse get() {
        return SubscriptionPriceResponse.from(pricing.pro());
    }

    @Operation(summary = "Set the monthly price of PRO", description = "PLATFORM_ADMIN only. Applies to charges made "
            + "afterwards; charges already made keep their amount.")
    @ApiResponse(responseCode = "200", description = "Updated price")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/api/v1/platform/subscription-price")
    @PlatformAdminOnly
    public SubscriptionPriceResponse set(@Valid @RequestBody SetSubscriptionPriceRequest request) {
        UUID actorId = PlatformCurrentAdmin.requireAdminId();
        String email = platformAdminService.me(actorId).email();
        return SubscriptionPriceResponse.from(pricing.setPro(actorId, email, request.monthlyPrice(), request.currency()));
    }
}
