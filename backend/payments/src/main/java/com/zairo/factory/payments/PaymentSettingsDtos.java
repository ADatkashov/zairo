package com.zairo.factory.payments;

import com.zairo.factory.depositpolicy.DepositType;
import com.zairo.factory.depositpolicy.DepositValueType;
import com.zairo.factory.depositpolicy.PaymentSettings;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.UUID;

public final class PaymentSettingsDtos {

    private PaymentSettingsDtos() {
    }

    public record UpdatePaymentSettingsRequest(
            @NotNull @Schema(description = "Type of advance payment required") DepositType depositType,
            @Schema(description = "Type of deposit value (percentage or fixed amount). Required if depositType is DEPOSIT")
            DepositValueType depositValueType,
            @Schema(description = "Deposit value. For PERCENTAGE: 0-100. For FIXED_AMOUNT: positive number. Required if depositType is DEPOSIT")
            BigDecimal depositValue) {
    }

    public record PaymentSettingsResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            DepositType depositType,
            DepositValueType depositValueType,
            @Schema(description = "For PERCENTAGE: 0-100. For FIXED_AMOUNT: positive amount in booking currency")
            BigDecimal depositValue) {
        static PaymentSettingsResponse from(PaymentSettings settings) {
            return new PaymentSettingsResponse(settings.getId(), settings.getProviderId(),
                    settings.getDepositType(), settings.getDepositValueType(), settings.getDepositValue());
        }
    }

    /** What a customer may see before booking: how much is charged up front. */
    public record DepositPolicyResponse(
            DepositType depositType,
            DepositValueType depositValueType,
            @Schema(description = "For PERCENTAGE: 0-100. For FIXED_AMOUNT: amount in booking currency")
            BigDecimal depositValue) {
        static DepositPolicyResponse from(PaymentSettings settings) {
            return new DepositPolicyResponse(settings.getDepositType(), settings.getDepositValueType(),
                    settings.getDepositValue());
        }

        static DepositPolicyResponse none() {
            return new DepositPolicyResponse(DepositType.NO_PAYMENT, null, null);
        }
    }
}
