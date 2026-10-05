package com.zairo.factory.staff;

import com.zairo.factory.services.ServiceOffering;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public final class StaffDtos {

    private StaffDtos() {
    }

    // Bounds mirror staff's actual columns — display_name varchar(255) not
    // null, bio unbounded text (nullable), photo_url varchar(500) (nullable).
    public record CreateStaffFromUserRequest(
            @NotNull @Schema(description = "A registered user, found via GET /users/lookup.",
                    example = "550e8400-e29b-41d4-a716-446655440000") UUID userId) {
    }

    public record CreateStaffRequest(
            @NotBlank @Size(max = 255) @Schema(example = "Dr. Aliya Nurlanovna") String displayName,
            @Schema(description = "Optional.", example = "15 years, general dentistry.") String bio,
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

    public record StaffResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Dr. Aliya Nurlanovna") String displayName,
            @Schema(example = "15 years, general dentistry.") String bio,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String photoUrl,
            @Schema(description = "False once deactivated (soft-delete) — see DELETE /staff/{staffId}.")
            boolean active,
            Instant createdAt) {
        static StaffResponse from(Staff staff) {
            return new StaffResponse(staff.getId(), staff.getProviderId(), staff.getDisplayName(), staff.getBio(),
                    staff.getPhotoUrl(), staff.isActive(), staff.getCreatedAt());
        }
    }

    public record StaffServiceResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID serviceId,
            @Schema(example = "Consultation") String title,
            @Schema(example = "30") int durationMinutes,
            @Schema(example = "50.00") BigDecimal price,
            @Schema(example = "USD") String currency) {
        static StaffServiceResponse from(ServiceOffering service) {
            return new StaffServiceResponse(service.getId(), service.getTitle(), service.getDurationMinutes(),
                    service.getPrice(), service.getCurrency());
        }
    }
}
