package com.zairo.factory.auth;

import com.zairo.factory.users.Gender;
import com.zairo.factory.users.UserRole;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
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
            @Schema(example = "http://localhost:8080/api/v1/uploads/a1b2c3d4.jpg") String avatarUrl,
            @Schema(example = "1995-04-23", description = "Null when the customer hasn't entered it.") LocalDate birthDate,
            @Schema(description = "Null = not specified.") Gender gender,
            @Schema(description = "Opted in to birthday greetings, bonuses and offers.") boolean marketingConsent) {
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
                    + "with 409 if another account already uses it.", example = "aigerim@example.com") String email,
            @Past @Schema(description = "Null leaves the current birth date unchanged (see clearBirthDate).",
                    example = "1995-04-23") LocalDate birthDate,
            @Schema(description = "True removes the stored birth date.") Boolean clearBirthDate,
            @Schema(description = "Null leaves unchanged; NOT_SPECIFIED clears it.") Gender gender,
            @Schema(description = "Null leaves unchanged.") Boolean marketingConsent) {
    }

    public record GoogleAuthRequest(
            @NotBlank @Schema(description = "The Google ID token (JWT credential) obtained on-device via Google "
                    + "Sign-In — never a Google access token. Verified server-side against Google's own public "
                    + "keys; see docs/authentication.md.") String idToken,
            @Schema(description = "Role for a NEW account created by this call: CUSTOMER (default; the consumer app) or "
                    + "PROVIDER_OWNER (the business app). ADMIN is rejected. Ignored when the person already has an "
                    + "account - an existing account's role never changes.", example = "PROVIDER_OWNER")
            com.zairo.factory.users.UserRole role) {

        public GoogleAuthRequest(String idToken) {
            this(idToken, null);
        }
    }

    public record AppleAuthRequest(
            @NotBlank @Schema(description = "The Sign in with Apple identity token (JWT) obtained on-device. "
                    + "Verified server-side against Apple's published keys; see docs/authentication.md.")
            String identityToken,
            @Size(max = 255) @Schema(description = "Optional: Apple only gives the person's name to the app, never "
                    + "inside the token, and only on the very first sign-in. Used as display name when this "
                    + "creates a new account; ignored otherwise.", example = "Aigerim Bekova") String displayName,
            @Schema(description = "Role for a NEW account created by this call: CUSTOMER (default; the consumer app) or "
                    + "PROVIDER_OWNER (the business app). ADMIN is rejected. Ignored when the person already has an "
                    + "account - an existing account's role never changes.", example = "PROVIDER_OWNER")
            com.zairo.factory.users.UserRole role) {

        public AppleAuthRequest(String identityToken, String displayName) {
            this(identityToken, displayName, null);
        }
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

    public record PhoneStatusRequest(
            @NotBlank @Schema(example = "+7 700 123 45 67") String phone) {
    }

    public record PhoneStatusResponse(
            @Schema(description = "A ZAIRO account is already reachable through this phone.") boolean registered,
            @Schema(description = "That account has a password, so sign-in asks for it instead of an SMS code.")
            boolean hasPassword) {
    }

    public record PhonePasswordLoginRequest(
            @NotBlank @Schema(example = "+7 700 123 45 67") String phone,
            @NotBlank @Schema(example = "Password123") String password) {
    }

    public record PhoneRegisterRequest(
            @NotBlank @Schema(example = "+7 700 123 45 67") String phone,
            @NotBlank @Pattern(regexp = "\\d{6}") @Schema(description = "The 6-digit code just sent by SMS.",
                    example = "482913") String code,
            @NotBlank @Size(max = 255) @Schema(example = "Aigerim Bekova") String displayName,
            @NotBlank @Size(min = 8) @Schema(example = "Password123", minLength = 8) String password,
            @Schema(description = "Role for a NEW account created by this call: CUSTOMER (default; the consumer app) or "
                    + "PROVIDER_OWNER (the business app). ADMIN is rejected. Ignored when the person already has an "
                    + "account - an existing account's role never changes.", example = "PROVIDER_OWNER")
            com.zairo.factory.users.UserRole role) {

        public PhoneRegisterRequest(String phone, String code, String displayName, String password) {
            this(phone, code, displayName, password, null);
        }
    }

    public record PhoneResetPasswordRequest(
            @NotBlank @Schema(example = "+7 700 123 45 67") String phone,
            @NotBlank @Pattern(regexp = "\\d{6}") @Schema(description = "The 6-digit code just sent by SMS.",
                    example = "482913") String code,
            @NotBlank @Size(min = 8) @Schema(example = "NewPassword456", minLength = 8) String newPassword) {
    }

    public record LinkWithPasswordRequest(
            @NotNull @Schema(description = "GOOGLE or FACEBOOK.") IdentityProvider provider,
            @NotBlank @Schema(description = "The Google ID token / Facebook access token from the sign-in that "
                    + "was answered with 409 ACCOUNT_LINK_REQUIRED.") String token,
            @NotBlank @Schema(description = "Password of the existing account that owns the provider's email.")
            String password) {
    }

    public record SmsModeResponse(
            @Schema(description = "SMS codes are mocked (no real SMS is sent) - pre-production only.") boolean mock,
            @Schema(description = "The fixed code that works for every phone while mock is true; null otherwise.")
            String mockCode) {
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
