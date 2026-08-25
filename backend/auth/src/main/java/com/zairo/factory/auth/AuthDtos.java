package com.zairo.factory.auth;

import com.zairo.factory.users.UserRole;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public final class AuthDtos {

    private AuthDtos() {
    }

    // Field bounds mirror app_user's actual columns (email/display_name
    // varchar(255), phone varchar(50) — see V1 migration) and the minimum
    // password length both Flutter apps already enforce client-side
    // (validationPasswordMinLength: "At least 8 characters").
    public record RegisterRequest(
            @NotBlank @Email @Size(max = 255) @Schema(example = "aigerim@example.com") String email,
            @NotBlank @Size(min = 8) @Schema(example = "Password123", minLength = 8) String password,
            @NotBlank @Size(max = 255) @Schema(example = "Aigerim Bekova") String displayName,
            @Size(max = 50) @Schema(example = "+77001234567") String phone,
            @NotNull @Schema(description = "CUSTOMER or PROVIDER_OWNER only — ADMIN cannot self-register "
                    + "(AuthService rejects it with 400 AdminRoleNotSelfAssignable).", example = "CUSTOMER")
            UserRole role) {
    }

    public record LoginRequest(
            @NotBlank @Email @Schema(example = "aigerim@example.com") String email,
            @NotBlank @Schema(example = "Password123") String password) {
    }

    public record RefreshRequest(
            @NotBlank @Schema(description = "A refresh token previously issued by /auth/register or /auth/login.")
            String refreshToken) {
    }

    public record ForgotPasswordRequest(@NotBlank @Email @Schema(example = "aigerim@example.com") String email) {
    }

    public record ResetPasswordRequest(
            @NotBlank @Schema(description = "The code emailed by /auth/forgot-password (logged to the server "
                    + "console in local dev — no real email provider is wired up yet).")
            String token,
            @NotBlank @Size(min = 8) @Schema(example = "NewPassword456", minLength = 8) String newPassword) {
    }

    public record UserSummary(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "aigerim@example.com") String email,
            @Schema(example = "Aigerim Bekova") String displayName,
            UserRole role) {
    }

    public record TokenResponse(
            @Schema(description = "Short-lived — send as `Authorization: Bearer <accessToken>` on every "
                    + "authenticated request.", example = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI1NTBlODQwMC4uLiJ9.dGVzdA")
            String accessToken,
            @Schema(description = "Long-lived — exchange at POST /auth/refresh for a new access token once it "
                    + "expires. Do not send this to protected endpoints.",
                    example = "eyJhbGciOiJIUzI1NiJ9.eyJ0eXBlIjoicmVmcmVzaCJ9.dGVzdA")
            String refreshToken,
            UserSummary user) {
    }
}
