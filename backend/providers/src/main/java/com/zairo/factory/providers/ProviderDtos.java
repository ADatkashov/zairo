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
            @NotBlank @Size(max = 50) @Schema(description = "Free-form today, not an enum — \"beauty\" and "
                    + "\"auto\" are the two verticals with real functionality built on top of it so far.",
                    example = "beauty")
            String vertical,
            @Schema(example = "43.238293") Double latitude,
            @Schema(example = "76.945465") Double longitude,
            @Size(max = 255) @Schema(description = "A city code from GET /cities — where the business works. "
                    + "Optional; a business without one is listed in every city.", example = "almaty")
            String cityCode) {
        // Convenience constructors for callers that don't set a location /
        // city — keep every pre-existing call site (mostly tests) compiling
        // without a mechanical find-and-replace across the codebase.
        public CreateProviderRequest(UUID ownerUserId, String name, String vertical) {
            this(ownerUserId, name, vertical, null, null, null);
        }

        public CreateProviderRequest(UUID ownerUserId, String name, String vertical, Double latitude,
                Double longitude) {
            this(ownerUserId, name, vertical, latitude, longitude, null);
        }
    }

    public record UpdateProviderRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Aigerim Beauty Studio") String name,
            @Schema(example = "43.238293") Double latitude,
            @Schema(example = "76.945465") Double longitude,
            @Size(max = 2048) @Schema(description = "URL returned by POST /uploads. Null clears it.",
                    example = "http://localhost:8080/api/v1/uploads/a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d.jpg")
            String coverPhotoUrl,
            @Size(max = 255) @Schema(description = "A city code from GET /cities. Omit (or leave blank) to keep the "
                    + "current one; a business without a city is listed in every city.", example = "almaty")
            String cityCode,
            @Size(max = 255) @Schema(description = "Street address. Omit to keep, blank to clear.",
                    example = "Abay Ave 10, Almaty") String address,
            @Size(max = 50) @Schema(description = "Public phone. Omit to keep, blank to clear.",
                    example = "+7 701 000 00 00") String phone,
            @Size(max = 2000) @Schema(description = "About the business. Omit to keep, blank to clear.")
            String description,
            @Schema(description = "Opening hours: keys mon..sun, value HH:mm-HH:mm; a missing day means closed. "
                    + "Omit to keep, send {} to clear.", example = "{\"mon\":\"09:00-20:00\"}")
            java.util.Map<String, String> workingHours) {
        // Convenience constructors for existing callers (tests) that predate
        // coverPhotoUrl / cityCode — same back-compat pattern as
        // CreateProviderRequest above.
        public UpdateProviderRequest(String name, Double latitude, Double longitude) {
            this(name, latitude, longitude, null, null);
        }

        public UpdateProviderRequest(String name, Double latitude, Double longitude, String coverPhotoUrl) {
            this(name, latitude, longitude, coverPhotoUrl, null);
        }

        public UpdateProviderRequest(String name, Double latitude, Double longitude, String coverPhotoUrl,
                String cityCode) {
            this(name, latitude, longitude, coverPhotoUrl, cityCode, null, null, null, null);
        }
    }

    public record UpdateProviderStatusRequest(@NotNull ProviderStatus status) {
    }

    /**
     * The Control Center's version of the same action, with an optional
     * {@code reason} recorded on the audit log entry — see
     * {@code ProviderAdminController}. The legacy {@code UserRole.ADMIN}
     * path (PATCH /providers/{id}/status) keeps its own request shape rather
     * than being migrated onto this one; see that endpoint's own doc
     * comment for why both still exist.
     */
    public record PlatformSetProviderStatusRequest(
            @NotNull @Schema(example = "ACTIVE") ProviderStatus status,
            @Schema(description = "Recorded on the audit log entry for this action.") String reason) {
    }

    public record ProviderResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID ownerUserId,
            @Schema(example = "Aigerim Beauty Studio") String name,
            @Schema(example = "beauty") String vertical,
            ProviderStatus status,
            Instant createdAt,
            @Schema(example = "43.238293") Double latitude,
            @Schema(example = "76.945465") Double longitude,
            @Schema(description = "The catalog.BusinessType this provider was resolved to at creation time, from "
                    + "its vertical — null for providers created before the master catalog existed.",
                    example = "550e8400-e29b-41d4-a716-446655440000")
            UUID businessTypeId,
            @Schema(description = "Null until the owner sets one via PUT /providers/{id}.",
                    example = "http://localhost:8080/api/v1/uploads/a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d.jpg")
            String coverPhotoUrl,
            @Schema(description = "The city code the owner picked; null until they do.", example = "almaty")
            String cityCode,
            @Schema(example = "Abay Ave 10, Almaty") String address,
            @Schema(example = "+7 701 000 00 00") String phone,
            String description,
            @Schema(description = "Opening hours by weekday (mon..sun -> HH:mm-HH:mm); empty if not stated.")
            java.util.Map<String, String> workingHours) {
        static ProviderResponse from(Provider provider) {
            return new ProviderResponse(provider.getId(), provider.getOwnerUserId(), provider.getName(),
                    provider.getVertical(), provider.getStatus(), provider.getCreatedAt(), provider.getLatitude(),
                    provider.getLongitude(), provider.getBusinessTypeId(), provider.getCoverPhotoUrl(),
                    provider.getCityCode(), provider.getAddress(), provider.getPhone(), provider.getDescription(),
                    provider.getWorkingHours());
        }
    }
}
