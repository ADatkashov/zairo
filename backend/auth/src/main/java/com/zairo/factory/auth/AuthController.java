package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.ForgotPasswordRequest;
import com.zairo.factory.auth.AuthDtos.LoginRequest;
import com.zairo.factory.auth.AuthDtos.RefreshRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.auth.AuthDtos.ResetPasswordRequest;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UpdateAvatarRequest;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Authentication")
public class AuthController {

    private final AuthService authService;
    private final UserRepository userRepository;

    public AuthController(AuthService authService, UserRepository userRepository) {
        this.authService = authService;
        this.userRepository = userRepository;
    }

    @Operation(summary = "Register a new account", description = """
            Creates a user and returns access/refresh tokens immediately — no separate login call needed. \
            `role` must be CUSTOMER or PROVIDER_OWNER; ADMIN cannot self-register.

            **Workflow**: this is step 1 of `Register -> Login -> Get current user` — the returned \
            `accessToken` already works for `GET /auth/me`, so step 2 (a separate login) is only needed \
            after the token expires.""")
    @ApiResponse(responseCode = "201", description = "Account created")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "409", description = "This email is already registered.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @Operation(summary = "Log in", description = "Exchanges email + password for a fresh pair of tokens.")
    @ApiResponse(responseCode = "200", description = "Authenticated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "Wrong email or password.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request.email(), request.password());
    }

    @Operation(summary = "Refresh an access token",
            description = "Exchanges a still-valid refresh token for a brand new access + refresh pair, without "
                    + "requiring the password again.")
    @ApiResponse(responseCode = "200", description = "New token pair issued")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "The refresh token is invalid, expired, or already used.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return authService.refresh(request.refreshToken());
    }

    @Operation(summary = "Request a password reset code", description = """
            Always returns 200, whether or not the email belongs to a real account — this deliberately \
            avoids leaking which emails are registered. If the account exists, a reset code is generated \
            and "emailed" (in local dev, no real mail provider is configured — read the code straight out \
            of the server log: `EMAIL to=... subject="Reset your Factory password"`).""")
    @ApiResponse(responseCode = "200", description = "Request accepted (regardless of whether the email exists)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @PostMapping("/api/v1/auth/forgot-password")
    public void forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request.email());
    }

    @Operation(summary = "Reset a password with a code",
            description = "Consumes the one-time code from /auth/forgot-password and sets a new password. "
                    + "The code expires an hour after it was requested and can only be used once.")
    @ApiResponse(responseCode = "200", description = "Password changed")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "The code is invalid, expired, or already used.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/reset-password")
    public void resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request.token(), request.newPassword());
    }

    @Operation(summary = "Get the current user", description = "Resolves the caller's own account from the "
            + "access token in the Authorization header. The standard way to check \"who am I / am I still "
            + "logged in\" without decoding the JWT client-side.")
    @ApiResponse(responseCode = "200", description = "The caller's account")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/auth/me")
    public UserSummary me(HttpServletRequest request) {
        UUID userId = (UUID) request.getAttribute(JwtAuthFilter.USER_ID_ATTRIBUTE);
        if (userId == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User no longer exists"));
        return new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole(),
                user.getAvatarUrl());
    }

    @Operation(summary = "Update the current user's avatar", description = "Upload the image via POST /uploads "
            + "first, then pass its returned url here. Pass null/blank to remove the avatar.")
    @ApiResponse(responseCode = "200", description = "Avatar updated")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @PatchMapping("/api/v1/auth/me/avatar")
    public UserSummary updateAvatar(@Valid @RequestBody UpdateAvatarRequest request, HttpServletRequest httpRequest) {
        UUID userId = (UUID) httpRequest.getAttribute(JwtAuthFilter.USER_ID_ATTRIBUTE);
        if (userId == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
        }
        return authService.updateAvatar(userId, request.avatarUrl());
    }
}
