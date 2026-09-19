package com.zairo.factory.auth;

import com.zairo.factory.users.UserRole;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
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
            UserRole role,
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String avatarUrl) {
    }

    public record UpdateAvatarRequest(
            @Size(max = 2048) @Schema(description = "Upload via POST /uploads first, then pass its returned url "
                    + "here. Null/blank removes the avatar.",
                    example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg")
            String avatarUrl) {
    }

    public record UpdateProfileRequest(
            @Size(max = 255) @Schema(description = "Null/blank leaves the current display name unchanged.",
                    example = "Aigerim Bekova") String displayName,
            @Email @Size(max = 255) @Schema(description = "Null/blank leaves the current email unchanged. Rejected "
                    + "with 409 if another account already uses it.", example = "aigerim@example.com") String email) {
    }

    public record GoogleAuthRequest(
            @NotBlank @Schema(description = "The Google ID token (JWT credential) obtained on-device via Google "
                    + "Sign-In — never a Google access token. Verified server-side against Google's own public "
                    + "keys; see docs/authentication.md.") String idToken) {
    }

    public record FacebookAuthRequest(
            @NotBlank @Schema(description = "The Facebook user access token obtained on-device via the Facebook "
                    + "Login SDK. Verified server-side against the Graph API's debug_token endpoint; see "
                    + "docs/authentication.md.") String accessToken) {
    }

    public record RequestPhoneOtpRequest(
            @NotBlank @Schema(description = "Any reasonable local or international format — normalized "
                    + "server-side to E.164.", example = "+7 700 123 45 67") String phone) {
    }

    public record VerifyPhoneOtpRequest(
            @NotBlank @Schema(example = "+7 700 123 45 67") String phone,
            @NotBlank @Pattern(regexp = "\\d{6}") @Schema(description = "The 6-digit code just sent by SMS.",
                    example = "482913") String code) {
    }

    public record IdentitySummary(
            @Schema(description = "Which sign-in method this is.") IdentityProvider provider,
            Instant linkedAt) {
    }

    public record IdentitiesResponse(List<IdentitySummary> identities) {
    }

    public record BiometricAuditRequest(
            @NotNull @Schema(description = "Whether the person just enabled or disabled biometric unlock on their "
                    + "device. Audit-only — see AuthAuditLog; ZAIRO's backend never stores biometric enrollment "
                    + "itself, that's entirely local to the device (see docs/authentication.md's Biometric "
                    + "architecture section).") Boolean enabled) {
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
