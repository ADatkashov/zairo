package com.zairo.factory.payments;

import com.zairo.factory.payments.BusinessPayoutDtos.MarkFailedRequest;
import com.zairo.factory.payments.BusinessPayoutDtos.MarkPaidRequest;
import com.zairo.factory.payments.BusinessPayoutDtos.PayoutResponse;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Platform admin's settlement console — see ADR-0007: Freedom Pay's own
 * business-payout/G2G API isn't confirmed by this integration, so a
 * platform admin performs the actual bank transfer outside this system and
 * records the outcome here. Reads are PLATFORM_ADMIN or PLATFORM_SUPPORT
 * (same as {@code PaymentAdminController}); every mutation is
 * PLATFORM_ADMIN-only.
 */
@RestController
@Tag(name = "Platform Admin — Payouts")
public class BusinessPayoutAdminController {

    private final BusinessPayoutRepository payoutRepository;
    private final BusinessPayoutService payoutService;

    public BusinessPayoutAdminController(BusinessPayoutRepository payoutRepository, BusinessPayoutService payoutService) {
        this.payoutRepository = payoutRepository;
        this.payoutService = payoutService;
    }

    @Operation(summary = "List payouts, optionally by status", description = "Ordered most-recent first.")
    @ApiResponse(responseCode = "200", description = "Payouts")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/platform/payouts")
    public List<PayoutResponse> list(
            @Parameter(description = "Filter by status; omit for every payout.") @RequestParam(required = false) BusinessPayoutStatus status,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAnyRole(httpRequest);
        List<BusinessPayout> payouts = status == null ? payoutRepository.findAll()
                : payoutRepository.findByStatusOrderByCreatedAtDesc(status);
        return payouts.stream().map(PayoutResponse::from).toList();
    }

    @Operation(summary = "Mark a payout PROCESSING", description = "A platform admin is about to perform the "
            + "bank transfer. Optional step — mark-paid can be called directly from PAYABLE too.")
    @ApiResponse(responseCode = "200", description = "Now PROCESSING")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "Already PAID (terminal).")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/payouts/{payoutId}/mark-processing")
    public PayoutResponse markProcessing(@PathVariable UUID payoutId, HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        return PayoutResponse.from(payoutService.markProcessing(payoutId));
    }

    @Operation(summary = "Mark a payout PAID", description = "Records that the business actually received the "
            + "money — the platform admin performed (or confirmed) the transfer outside this system; see "
            + "ADR-0007 for why this isn't an automated Freedom Pay call today.")
    @ApiResponse(responseCode = "200", description = "Now PAID")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "Already PAID (terminal).")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/payouts/{payoutId}/mark-paid")
    public PayoutResponse markPaid(@PathVariable UUID payoutId, @RequestBody(required = false) MarkPaidRequest request,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        String reference = request == null ? null : request.providerReference();
        return PayoutResponse.from(payoutService.markPaid(payoutId, reference));
    }

    @Operation(summary = "Mark a payout FAILED", description = "Retriable — a later mark-processing/mark-paid "
            + "call on the same payout is still allowed, same as Payment.REFUND_FAILED.")
    @ApiResponse(responseCode = "200", description = "Now FAILED")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @ApiResponse(responseCode = "409", description = "Already PAID (terminal).")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/platform/payouts/{payoutId}/mark-failed")
    public PayoutResponse markFailed(@PathVariable UUID payoutId, @RequestBody(required = false) MarkFailedRequest request,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        String reason = request == null ? null : request.reason();
        return PayoutResponse.from(payoutService.markFailed(payoutId, reason));
    }
}
