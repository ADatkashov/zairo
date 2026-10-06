package com.zairo.factory.vertical.beauty;

import com.zairo.factory.services.ServiceOffering;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class MasterDtos {

    private MasterDtos() {
    }

    // Bounds mirror beauty_master's actual columns (V11 migration) —
    // display_name varchar(255) not null, bio unbounded text (nullable),
    // photo_url varchar(500) (nullable).
    public record CreateMasterRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Jamie Stylist") String displayName,
            @Schema(description = "Optional.", example = "10 years of experience in balayage and color.")
            String bio,
            @Size(max = 500) @Schema(description = "Optional — upload via POST /uploads first, then pass "
                    + "its returned url here.", example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg")
            String photoUrl) {
    }

    public record UpdatePhotoRequest(
            @Size(max = 500) @Schema(description = "Upload via POST /uploads first, then pass its returned url "
                    + "here. Null/blank removes the photo.",
                    example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg")
            String photoUrl) {
    }

    public record CreateMasterFromUserRequest(
            @NotNull @Schema(description = "A registered user, found via GET /users/lookup.",
                    example = "550e8400-e29b-41d4-a716-446655440000") UUID userId) {
    }

    public record MasterResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Jamie Stylist") String displayName,
            @Schema(example = "10 years of experience in balayage and color.") String bio,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String photoUrl,
            @Schema(description = "False once deactivated (soft-delete) — see DELETE /beauty/masters/{masterId}.")
            boolean active,
            Instant createdAt) {
        static MasterResponse from(Master master) {
            return new MasterResponse(master.getId(), master.getProviderId(), master.getDisplayName(),
                    master.getBio(), master.getPhotoUrl(), master.isActive(), master.getCreatedAt());
        }
    }

    // Bounds mirror beauty_portfolio_item's columns (V12 migration) —
    // image_url varchar(500) not null, caption varchar(500) (nullable).
    public record AddPortfolioItemRequest(
            @NotBlank @Size(max = 500) @Schema(description = "Upload via POST /uploads first, then pass its "
                    + "returned url here.", example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg")
            String imageUrl,
            @Size(max = 500) @Schema(description = "Optional.", example = "Balayage look") String caption) {
    }

    public record PortfolioItemResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID masterId,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String imageUrl,
            @Schema(example = "Balayage look") String caption,
            Instant createdAt) {
        static PortfolioItemResponse from(PortfolioItem item) {
            return new PortfolioItemResponse(item.getId(), item.getMasterId(), item.getImageUrl(),
                    item.getCaption(), item.getCreatedAt());
        }
    }

    public record MasterServiceResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "Classic Manicure") String title,
            @Schema(example = "60") int durationMinutes,
            @Schema(example = "25.00") BigDecimal price,
            @Schema(example = "USD") String currency) {
        static MasterServiceResponse from(ServiceOffering service) {
            return new MasterServiceResponse(service.getId(), service.getTitle(), service.getDurationMinutes(),
                    service.getPrice(), service.getCurrency());
        }
    }
}
