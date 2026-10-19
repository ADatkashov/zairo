package com.zairo.factory.payments;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.payments.BusinessPayoutDtos.PayoutResponse;
import com.zairo.factory.providers.OwnsProvider;
import com.zairo.factory.providers.ProviderOwnership;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/**
 * Business-facing settlement visibility — "GET payable amount" / "GET
 * settlement status" from the task this module was built for. Read-only:
 * a business never marks its own payout PAID (see
 * {@code BusinessPayoutAdminController}) — same reasoning as a customer
 * never setting a payment's own amount.
 */
@RestController
@Tag(name = "Providers — Payouts")
public class BusinessPayoutController {

    private final BusinessPayoutRepository payoutRepository;
    private final ProviderOwnership providerOwnership;

    public BusinessPayoutController(BusinessPayoutRepository payoutRepository, ProviderOwnership providerOwnership) {
        this.payoutRepository = payoutRepository;
        this.providerOwnership = providerOwnership;
    }

    @Operation(summary = "List a provider's settlement payouts", description = """
            One row per COMPLETED booking whose business share is payable — ordered most-recent first. \
            A booking that's cancelled/refunded before completion never appears here at all (see BusinessPayout's \
            own doc comment): this list is strictly "money owed or paid for service actually delivered", not \
            every booking's payment.

            Restricted to the provider's own owner.""")
    @ApiResponse(responseCode = "200", description = "The provider's payouts")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/payouts")
    @OwnsProvider
    public List<PayoutResponse> listForProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId) {
        UUID callerId = CurrentUser.requireUserId();
        return payoutRepository.findByProviderIdOrderByCreatedAtDesc(providerId).stream()
                .map(PayoutResponse::from)
                .toList();
    }
}
