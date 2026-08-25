package com.zairo.factory.services;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.UUID;

public final class ServiceOfferingDtos {

    private ServiceOfferingDtos() {
    }

    // title bound mirrors the service table's title varchar(255) (V3
    // migration); currency mirrors its varchar(3) column and the ISO 4217
    // code length Money ultimately validates against; price non-negative
    // mirrors Money's own requireNonNegative check (currently thrown as an
    // uncaught IllegalArgumentException -> undocumented 500 without this).
    public record CreateServiceRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Classic Manicure") String title,
            @Schema(example = "60") int durationMinutes,
            @NotNull @DecimalMin("0") @Schema(example = "25.00") BigDecimal price,
            @NotBlank @Size(min = 3, max = 3)
            @Schema(description = "ISO 4217 currency code.", example = "USD") String currency) {
    }

    public record UpdateServiceRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Classic Manicure") String title,
            @Schema(example = "60") int durationMinutes,
            @NotNull @DecimalMin("0") @Schema(example = "25.00") BigDecimal price,
            @NotBlank @Size(min = 3, max = 3) @Schema(example = "USD") String currency) {
    }

    public record ServiceResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Classic Manicure") String title,
            @Schema(example = "60") int durationMinutes,
            @Schema(example = "25.00") BigDecimal price,
            @Schema(example = "USD") String currency,
            @Schema(description = "False once deactivated (soft-delete) — see DELETE /services/{id}.")
            boolean active) {
        static ServiceResponse from(ServiceOffering service) {
            return new ServiceResponse(service.getId(), service.getProviderId(), service.getTitle(),
                    service.getDurationMinutes(), service.getPrice(), service.getCurrency(), service.isActive());
        }
    }
}
