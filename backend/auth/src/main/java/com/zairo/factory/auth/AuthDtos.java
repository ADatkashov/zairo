package com.zairo.factory.auth;

import com.zairo.factory.users.UserRole;
import java.util.UUID;

public final class AuthDtos {

    private AuthDtos() {
    }

    public record RegisterRequest(String email, String password, String displayName, String phone,
            UserRole role) {
    }

    public record LoginRequest(String email, String password) {
    }

    public record RefreshRequest(String refreshToken) {
    }

    public record ForgotPasswordRequest(String email) {
    }

    public record ResetPasswordRequest(String token, String newPassword) {
    }

    public record UserSummary(UUID id, String email, String displayName, UserRole role) {
    }

    public record TokenResponse(String accessToken, String refreshToken, UserSummary user) {
    }
}
