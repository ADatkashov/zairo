package com.zairo.factory.payments;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public final class CommissionDtos {

    private CommissionDtos() {
    }

    public record SetCommissionRequest(
            @Schema(description = "Commission in percent of the payment amount, 0..100 with at most 2 decimals "
                    + "(10 = 10%, 0 = no commission).", example = "7.5")
            @NotNull @DecimalMin("0") @DecimalMax("100") @Digits(integer = 3, fraction = 2)
            BigDecimal ratePercent) {
    }

    public record CategoryCommission(
            UUID categoryId,
            String code,
            String nameKk,
            String nameRu,
            String nameEn,
            @Schema(description = "This category's own override in percent, or null when it follows the default.")
            BigDecimal overridePercent,
            @Schema(description = "The rate actually applied to this category's bookings, in percent.")
            BigDecimal effectivePercent) {
    }

    public record CommissionSettingsResponse(
            @Schema(description = "Platform-wide default in percent — applies to every category without an override.")
            BigDecimal defaultPercent,
            List<CategoryCommission> categories) {
    }
}
