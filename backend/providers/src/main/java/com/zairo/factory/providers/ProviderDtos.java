package com.zairo.factory.providers;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class ProviderDtos {

    private ProviderDtos() {
    }

    // name/vertical bounds mirror the provider table's actual columns
    // (varchar(255)/varchar(50) — see V2 migration). latitude/longitude
    // have no range check in the DB or service layer today, so left
    // unconstrained rather than inventing one.
    public record CreateProviderRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID ownerUserId,
            @NotBlank @Size(max = 255) @Schema(example = "Aigerim Beauty Studio") String name,
            @NotBlank @Size(max = 50) @Schema(description = "Free-form today, not an enum — \"beauty\" is the "
                    + "only vertical with real functionality built on top of it so far.", example = "beauty")
            String vertical,
            @Schema(example = "43.238293") Double latitude,
            @Schema(example = "76.945465") Double longitude) {
        // Convenience constructor for callers that don't set a location —
        // keeps every pre-existing 3-arg call site (mostly tests) compiling
        // without a mechanical find-and-replace across the codebase.
        public CreateProviderRequest(UUID ownerUserId, String name, String vertical) {
            this(ownerUserId, name, vertical, null, null);
        }
    }

    public record UpdateProviderRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Aigerim Beauty Studio") String name,
            @Schema(example = "43.238293") Double latitude,
            @Schema(example = "76.945465") Double longitude) {
    }

    public record UpdateProviderStatusRequest(@NotNull ProviderStatus status) {
    }

    public record ProviderResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID ownerUserId,
            @Schema(example = "Aigerim Beauty Studio") String name,
            @Schema(example = "beauty") String vertical,
            ProviderStatus status,
            Instant createdAt,
            @Schema(example = "43.238293") Double latitude,
            @Schema(example = "76.945465") Double longitude) {
        static ProviderResponse from(Provider provider) {
            return new ProviderResponse(provider.getId(), provider.getOwnerUserId(), provider.getName(),
                    provider.getVertical(), provider.getStatus(), provider.getCreatedAt(), provider.getLatitude(),
                    provider.getLongitude());
        }
    }
}
