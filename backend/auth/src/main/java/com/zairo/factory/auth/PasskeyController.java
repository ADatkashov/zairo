package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.PasskeyAvailabilityResponse;
import com.zairo.factory.auth.AuthDtos.PasskeyCeremonyResponse;
import com.zairo.factory.auth.AuthDtos.PasskeyLoginFinishRequest;
import com.zairo.factory.auth.AuthDtos.PasskeyRegisterFinishRequest;
import com.zairo.factory.auth.AuthDtos.PasskeySummary;
import com.zairo.factory.auth.AuthDtos.PasskeysResponse;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
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
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Passkeys (WebAuthn): register one while signed in, then sign in with it.
 * Each ceremony is two calls (start -> authenticator -> finish) tied together
 * by a single-use, short-lived {@code ceremonyId}. See PasskeyService.
 */
@RestController
@Tag(name = "Authentication")
public class PasskeyController {

    private final PasskeyService passkeyService;

    PasskeyController(PasskeyService passkeyService) {
        this.passkeyService = passkeyService;
    }

    @Operation(summary = "Are passkeys available on this server?", description = "Lets the app hide the passkey "
            + "buttons when app.passkey.rp-id is not configured.")
    @ApiResponse(responseCode = "200", description = "Availability")
    @GetMapping("/api/v1/auth/passkeys/availability")
    public PasskeyAvailabilityResponse availability() {
        return new PasskeyAvailabilityResponse(passkeyService.isEnabled());
    }

    @Operation(summary = "Start creating a passkey for the current user")
    @ApiResponse(responseCode = "200", description = "Creation options for the platform authenticator")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "503", description = "Passkeys are not configured.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auth/passkeys/register/start")
    public PasskeyCeremonyResponse startRegistration(HttpServletRequest httpRequest) {
        PasskeyService.Started started = passkeyService.startRegistration(CurrentUser.requireUserId(httpRequest));
        return new PasskeyCeremonyResponse(started.ceremonyId(), started.options());
    }

    @Operation(summary = "Finish creating a passkey")
    @ApiResponse(responseCode = "200", description = "Passkey saved")
    @ApiResponse(responseCode = "401", description = "Missing/invalid access token, or the authenticator's response "
            + "did not verify.", content = @Content(mediaType = "application/json",
                    schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auth/passkeys/register/finish")
    public PasskeySummary finishRegistration(@Valid @RequestBody PasskeyRegisterFinishRequest request,
            HttpServletRequest httpRequest) {
        PasskeyService.PasskeyView view = passkeyService.finishRegistration(CurrentUser.requireUserId(httpRequest),
                request.ceremonyId(), request.credential(), request.name());
        return new PasskeySummary(view.id(), view.name(), view.createdAt(), view.lastUsedAt());
    }

    @Operation(summary = "Start signing in with a passkey", description = "No username needed: the device offers "
            + "the person's passkeys for this app.")
    @ApiResponse(responseCode = "200", description = "Request options for the platform authenticator")
    @ApiResponse(responseCode = "503", description = "Passkeys are not configured.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/passkeys/login/start")
    public PasskeyCeremonyResponse startLogin() {
        PasskeyService.Started started = passkeyService.startLogin();
        return new PasskeyCeremonyResponse(started.ceremonyId(), started.options());
    }

    @Operation(summary = "Finish signing in with a passkey")
    @ApiResponse(responseCode = "200", description = "Signed in")
    @ApiResponse(responseCode = "401", description = "The authenticator's response did not verify, or the request "
            + "expired/was already used.", content = @Content(mediaType = "application/json",
                    schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/passkeys/login/finish")
    public TokenResponse finishLogin(@Valid @RequestBody PasskeyLoginFinishRequest request) {
        return passkeyService.finishLogin(request.ceremonyId(), request.credential());
    }

    @Operation(summary = "List the current user's passkeys")
    @ApiResponse(responseCode = "200", description = "The user's passkeys")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/auth/passkeys")
    public PasskeysResponse list(HttpServletRequest httpRequest) {
        return new PasskeysResponse(passkeyService.list(CurrentUser.requireUserId(httpRequest)).stream()
                .map(v -> new PasskeySummary(v.id(), v.name(), v.createdAt(), v.lastUsedAt())).toList());
    }

    @Operation(summary = "Remove one of the current user's passkeys")
    @ApiResponse(responseCode = "204", description = "Removed")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", description = "No such passkey for this user.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/auth/passkeys/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id, HttpServletRequest httpRequest) {
        passkeyService.delete(CurrentUser.requireUserId(httpRequest), id);
    }
}
