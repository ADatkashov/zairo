package com.zairo.factory.users;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class UserDtos {

    private UserDtos() {
    }

    // Bounds mirror app_user's actual columns (email/display_name
    // varchar(255), phone varchar(50) — see V1 migration).
    public record CreateUserRequest(
            @NotBlank @Email @Size(max = 255) @Schema(example = "aigerim@example.com") String email,
            @Size(max = 50) @Schema(example = "+77001234567") String phone,
            @NotBlank @Size(max = 255) @Schema(example = "Aigerim Bekova") String displayName,
            @NotNull UserRole role) {
    }

    public record UserResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "aigerim@example.com") String email,
            @Schema(example = "+77001234567") String phone,
            @Schema(example = "Aigerim Bekova") String displayName,
            UserRole role,
            Instant createdAt,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String avatarUrl) {
        static UserResponse from(User user) {
            return new UserResponse(user.getId(), user.getEmail(), user.getPhone(), user.getDisplayName(),
                    user.getRole(), user.getCreatedAt(), user.getAvatarUrl());
        }
    }

    /**
     * The minimum a business owner needs to pick an existing person (e.g. as a master): no email, phone
     * or role — those stay admin-only.
     */
    public record UserLookupResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "Aigerim Bekova") String displayName,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String avatarUrl) {
        static UserLookupResponse from(User user) {
            return new UserLookupResponse(user.getId(), user.getDisplayName(), user.getAvatarUrl());
        }
    }
}
