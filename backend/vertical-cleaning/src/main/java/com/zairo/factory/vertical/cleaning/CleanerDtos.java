package com.zairo.factory.vertical.cleaning;

import com.zairo.factory.services.ServiceOffering;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class CleanerDtos {

    private CleanerDtos() {
    }

    // Bounds mirror cleaning_cleaner's actual columns — display_name
    // varchar(255) not null, bio unbounded text (nullable), photo_url
    // varchar(500) (nullable).
    public record CreateCleanerRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Aigul Cleaner") String displayName,
            @Schema(description = "Optional.", example = "5 years of experience, eco-friendly products.")
            String bio,
            @Size(max = 500) @Schema(description = "Optional — upload via POST /uploads first, then pass "
                    + "its returned url here.", example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg")
            String photoUrl) {
    }

    public record CleanerResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Aigul Cleaner") String displayName,
            @Schema(example = "5 years of experience, eco-friendly products.") String bio,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String photoUrl,
            @Schema(description = "False once deactivated (soft-delete) — see DELETE /cleaning/cleaners/{cleanerId}.")
            boolean active,
            Instant createdAt) {
        static CleanerResponse from(Cleaner cleaner) {
            return new CleanerResponse(cleaner.getId(), cleaner.getProviderId(), cleaner.getDisplayName(),
                    cleaner.getBio(), cleaner.getPhotoUrl(), cleaner.isActive(), cleaner.getCreatedAt());
        }
    }

    public record CleanerServiceResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "General Cleaning") String title,
            @Schema(example = "240") int durationMinutes,
            @Schema(example = "18000.00") BigDecimal price,
            @Schema(example = "KZT") String currency) {
        static CleanerServiceResponse from(ServiceOffering service) {
            return new CleanerServiceResponse(service.getId(), service.getTitle(), service.getDurationMinutes(),
                    service.getPrice(), service.getCurrency());
        }
    }
}
