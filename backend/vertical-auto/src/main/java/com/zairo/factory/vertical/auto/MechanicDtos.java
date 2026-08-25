package com.zairo.factory.vertical.auto;

import com.zairo.factory.services.ServiceOffering;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class MechanicDtos {

    private MechanicDtos() {
    }

    // Bounds mirror auto_mechanic's actual columns (V19 migration) —
    // display_name varchar(255) not null, bio unbounded text (nullable),
    // photo_url varchar(500) (nullable).
    public record CreateMechanicRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Yerlan Mechanic") String displayName,
            @Schema(description = "Optional.", example = "12 years fixing German and Japanese engines.")
            String bio,
            @Size(max = 500) @Schema(description = "Optional — upload via POST /uploads first, then pass "
                    + "its returned url here.", example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg")
            String photoUrl) {
    }

    public record MechanicResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Yerlan Mechanic") String displayName,
            @Schema(example = "12 years fixing German and Japanese engines.") String bio,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String photoUrl,
            @Schema(description = "False once deactivated (soft-delete) — see DELETE /auto/mechanics/{mechanicId}.")
            boolean active,
            Instant createdAt) {
        static MechanicResponse from(Mechanic mechanic) {
            return new MechanicResponse(mechanic.getId(), mechanic.getProviderId(), mechanic.getDisplayName(),
                    mechanic.getBio(), mechanic.getPhotoUrl(), mechanic.isActive(), mechanic.getCreatedAt());
        }
    }

    public record MechanicServiceResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "Oil Change") String title,
            @Schema(example = "45") int durationMinutes,
            @Schema(example = "35.00") BigDecimal price,
            @Schema(example = "USD") String currency) {
        static MechanicServiceResponse from(ServiceOffering service) {
            return new MechanicServiceResponse(service.getId(), service.getTitle(), service.getDurationMinutes(),
                    service.getPrice(), service.getCurrency());
        }
    }
}
