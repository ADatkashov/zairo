package com.zairo.factory.ads;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.UUID;

public final class AdDtos {

    private AdDtos() {
    }

    /** What the customer app needs to draw a Home banner — nothing about moderation. */
    public record BannerResponse(UUID id, String title, String subtitle, String imageUrl, String videoUrl,
            boolean sponsored) {

        static BannerResponse from(AdBanner banner) {
            return new BannerResponse(banner.getId(), banner.getTitle(), banner.getSubtitle(), banner.getImageUrl(),
                    banner.getVideoUrl(), banner.getProviderId() != null);
        }
    }

    public record AdminBannerResponse(UUID id, UUID providerId, String title, String subtitle, String imageUrl,
            String videoUrl, String cityCode, Instant startsAt, Instant endsAt, int sortOrder, AdStatus status,
            String rejectionReason, Instant createdAt, Instant updatedAt) {

        static AdminBannerResponse from(AdBanner banner) {
            return new AdminBannerResponse(banner.getId(), banner.getProviderId(), banner.getTitle(),
                    banner.getSubtitle(), banner.getImageUrl(), banner.getVideoUrl(), banner.getCityCode(),
                    banner.getStartsAt(), banner.getEndsAt(), banner.getSortOrder(), banner.getStatus(),
                    banner.getRejectionReason(), banner.getCreatedAt(), banner.getUpdatedAt());
        }
    }

    /** {@code status} may only be DRAFT (the default) or ACTIVE for a banner the platform creates itself. */
    public record CreateBannerRequest(@NotBlank String title, String subtitle, @NotBlank String imageUrl,
            String videoUrl, String cityCode, @NotNull Instant startsAt, @NotNull Instant endsAt, Integer sortOrder,
            AdStatus status) {
    }

    public record UpdateBannerRequest(@NotBlank String title, String subtitle, @NotBlank String imageUrl,
            String videoUrl, String cityCode, @NotNull Instant startsAt, @NotNull Instant endsAt, Integer sortOrder) {
    }

    public record SetStatusRequest(@NotNull AdStatus status, String reason) {
    }
}
