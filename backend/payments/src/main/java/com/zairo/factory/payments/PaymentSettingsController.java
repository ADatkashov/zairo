package com.zairo.factory.payments;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.depositpolicy.PaymentSettings;
import com.zairo.factory.depositpolicy.PaymentSettingsService;
import com.zairo.factory.payments.PaymentSettingsDtos.DepositPolicyResponse;
import com.zairo.factory.payments.PaymentSettingsDtos.PaymentSettingsResponse;
import com.zairo.factory.payments.PaymentSettingsDtos.UpdatePaymentSettingsRequest;
import com.zairo.factory.providers.ProviderOwnership;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/payment-settings")
@Tag(name = "Payment Settings", description = "Manage payment settings (deposit policies) for providers")
public class PaymentSettingsController {

    private final PaymentSettingsService paymentSettingsService;
    private final ProviderOwnership providerOwnership;

    public PaymentSettingsController(PaymentSettingsService paymentSettingsService,
            ProviderOwnership providerOwnership) {
        this.paymentSettingsService = paymentSettingsService;
        this.providerOwnership = providerOwnership;
    }

    @GetMapping
    @Operation(summary = "Get payment settings for a provider", description = "Returns the current payment settings (deposit policy) for the specified provider")
    public PaymentSettingsResponse getSettings(@RequestParam UUID providerId, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        PaymentSettings settings = paymentSettingsService.getOrCreateSettings(providerId);
        return PaymentSettingsResponse.from(settings);
    }

    @GetMapping("/public")
    @Operation(summary = "Get a provider's deposit policy (customer-facing)", description = "Lets a customer see how much is charged up front before booking. No authentication required; a provider with no settings yet reports NO_PAYMENT.")
    public DepositPolicyResponse getPublicDepositPolicy(@RequestParam UUID providerId) {
        return paymentSettingsService.findSettings(providerId)
                .map(DepositPolicyResponse::from)
                .orElseGet(DepositPolicyResponse::none);
    }

    @PutMapping
    @Operation(summary = "Update payment settings for a provider", description = "Set the deposit policy for new bookings at this provider")
    public PaymentSettingsResponse updateSettings(@RequestParam UUID providerId,
            @Valid @RequestBody UpdatePaymentSettingsRequest request, HttpServletRequest httpRequest) {
        providerOwnership.requireOwner(providerId, CurrentUser.requireUserId(httpRequest));
        PaymentSettings settings = paymentSettingsService.updateSettings(providerId, request.depositType(),
                request.depositValueType(), request.depositValue());
        return PaymentSettingsResponse.from(settings);
    }
}
