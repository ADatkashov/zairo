package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.AppleAuthRequest;
import com.zairo.factory.auth.AuthDtos.FacebookAuthRequest;
import com.zairo.factory.auth.AuthDtos.GoogleAuthRequest;
import com.zairo.factory.auth.AuthDtos.LinkWithPasswordRequest;
import com.zairo.factory.auth.AuthDtos.PhonePasswordLoginRequest;
import com.zairo.factory.auth.AuthDtos.PhoneRegisterRequest;
import com.zairo.factory.auth.AuthDtos.PhoneResetPasswordRequest;
import com.zairo.factory.auth.AuthDtos.PhoneStatusRequest;
import com.zairo.factory.auth.AuthDtos.PhoneStatusResponse;
import com.zairo.factory.auth.AuthDtos.RequestPhoneOtpRequest;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.auth.AuthDtos.VerifyPhoneOtpRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Multi-provider sign-in and account linking — Google, Facebook, and phone
 * + OTP — on top of the same {@code app_user}/session model AuthController
 * already uses (see IdentityService's doc comment). Deliberately a
 * separate controller/tag rather than folding these onto AuthController:
 * password auth and provider auth are two independently-readable groups of
 * endpoints under the same {@code /api/v1/auth} prefix, not two different
 * APIs.
 *
 * <p>Login vs. link is which endpoint you call, not a hidden branch on
 * whether an Authorization header happens to be present: {@code POST
 * /auth/google} always logs in/registers, {@code POST
 * /auth/identities/google} always links to the caller's existing session.
 * Same split for Facebook and phone.
 */
@RestController
@Tag(name = "Authentication")
public class IdentityController {

    private final IdentityService identityService;
    private final int trustedProxyHops;

    public IdentityController(IdentityService identityService,
            @Value("${app.otp.trusted-proxy-hops:1}") int trustedProxyHops) {
        this.identityService = identityService;
        this.trustedProxyHops = trustedProxyHops;
    }

    @Operation(summary = "Sign in or register with Google", description = """
            Exchanges a Google ID token for a ZAIRO session — logs in if this Google account is already linked \
            to a ZAIRO user, otherwise creates a new CUSTOMER account for it. The ID token is verified \
            server-side (signature, issuer, audience, expiration — see GoogleIdTokenVerifierAdapter); nothing \
            the client claims about the identity (email, name) is trusted without that verification.

            If the verified, provider-confirmed email already belongs to a different existing ZAIRO account, \
            this is rejected with 409 rather than silently merged — log in with the existing method first, then \
            call POST /auth/identities/google to link Google to it explicitly.""")
    @ApiResponse(responseCode = "200", description = "Signed in (existing or newly created account)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "Invalid, expired, or wrong-audience/issuer Google credential.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "This email already belongs to a different existing account.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/google")
    public TokenResponse googleSignIn(@Valid @RequestBody GoogleAuthRequest request) {
        return identityService.loginOrRegisterWithGoogle(request.idToken());
    }

    @Operation(summary = "Link a Google account to the current user", description = "Attaches a verified Google "
            + "identity to the caller's own account. 409 if that Google account is already linked to someone "
            + "else; a no-op success if it's already linked to the caller.")
    @ApiResponse(responseCode = "200", description = "Linked (or already was)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "409", description = "Already linked to a different account.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auth/identities/google")
    public UserSummary linkGoogle(@Valid @RequestBody GoogleAuthRequest request, HttpServletRequest httpRequest) {
        UUID userId = CurrentUser.requireUserId(httpRequest);
        return identityService.linkGoogle(userId, request.idToken());
    }

    @Operation(summary = "Sign in or register with Apple", description = """
            Exchanges a Sign in with Apple identity token for a ZAIRO session - same shape as POST /auth/google. \
            The token's signature, issuer, audience and expiry are verified server-side against Apple's published \
            keys (see AppleIdTokenVerifierAdapter). A verified email that already belongs to another account is \
            handled like Google: joined automatically if that email is verified, otherwise 409 \
            ACCOUNT_LINK_REQUIRED.""")
    @ApiResponse(responseCode = "200", description = "Signed in (existing or newly created account)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "Invalid, expired, or wrong-audience Apple credential.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "ACCOUNT_LINK_REQUIRED - confirm the existing account's password.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/apple")
    public TokenResponse appleSignIn(@Valid @RequestBody AppleAuthRequest request) {
        return identityService.loginOrRegisterWithApple(request.identityToken(), request.displayName());
    }

    @Operation(summary = "Link an Apple account to the current user")
    @ApiResponse(responseCode = "200", description = "Linked (or already was)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "409", description = "Already linked to a different account.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auth/identities/apple")
    public UserSummary linkApple(@Valid @RequestBody AppleAuthRequest request, HttpServletRequest httpRequest) {
        UUID userId = CurrentUser.requireUserId(httpRequest);
        return identityService.linkApple(userId, request.identityToken());
    }

    @Operation(summary = "Sign in or register with Facebook", description = """
            Exchanges a Facebook user access token for a ZAIRO session — same shape as POST /auth/google. The \
            token is verified against the Graph API's debug_token endpoint (confirms it's valid, live, and was \
            issued to ZAIRO's own Facebook app) before any profile field is trusted — see \
            FacebookGraphIdentityVerifier.""")
    @ApiResponse(responseCode = "200", description = "Signed in (existing or newly created account)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "Invalid or unverifiable Facebook credential.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "This email already belongs to a different existing account.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/facebook")
    public TokenResponse facebookSignIn(@Valid @RequestBody FacebookAuthRequest request) {
        return identityService.loginOrRegisterWithFacebook(request.accessToken());
    }

    @Operation(summary = "Link a Facebook account to the current user")
    @ApiResponse(responseCode = "200", description = "Linked (or already was)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "409", description = "Already linked to a different account.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auth/identities/facebook")
    public UserSummary linkFacebook(@Valid @RequestBody FacebookAuthRequest request, HttpServletRequest httpRequest) {
        UUID userId = CurrentUser.requireUserId(httpRequest);
        return identityService.linkFacebook(userId, request.accessToken());
    }

    @Operation(summary = "Request an SMS OTP for a phone number", description = """
            Always returns 204 whether or not this phone already has an account — see \
            AuthDtos.RequestPhoneOtpRequest and IdentityService.requestPhoneOtp's doc comment (no user-\
            enumeration signal here, same reasoning as POST /auth/forgot-password). Rate-limited per phone \
            number: a resend cooldown, and a cap on how many codes one phone can request per hour — both \
            surfaced as 429.""")
    @ApiResponse(responseCode = "204", description = "Requested (regardless of whether this phone is registered)")
    @ApiResponse(responseCode = "400", description = "Not a valid, dialable phone number.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "429", description = "Resend cooldown still active, or too many requests this hour.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/phone/request-otp")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void requestPhoneOtp(@Valid @RequestBody RequestPhoneOtpRequest request, HttpServletRequest httpRequest) {
        identityService.requestPhoneOtp(request.phone(), ClientIp.of(httpRequest, trustedProxyHops));
    }

    @Operation(summary = "Verify a phone OTP and sign in or register", description = """
            Consumes the code from POST /auth/phone/request-otp — logs in if this phone is already linked to a \
            ZAIRO user, otherwise creates a new CUSTOMER account for it (displayName defaults to the phone \
            number; complete it later via PATCH /auth/me). The code is single-use, short-lived, and locked out \
            after too many wrong attempts — see PhoneOtpService.""")
    @ApiResponse(responseCode = "200", description = "Signed in (existing or newly created account)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "Wrong/already-used code.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "429", description = "Too many wrong attempts against the current code.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/phone/verify-otp")
    public TokenResponse verifyPhoneOtp(@Valid @RequestBody VerifyPhoneOtpRequest request) {
        return identityService.loginOrRegisterWithPhone(request.phone(), request.code());
    }

    @Operation(summary = "Verify a phone OTP and link it to the current user")
    @ApiResponse(responseCode = "200", description = "Linked (or already was)")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", description = "Wrong/already-used code, or missing/invalid access token.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "Already linked to a different account.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "429", description = "Too many wrong attempts against the current code.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/auth/identities/phone/verify-otp")
    public UserSummary linkPhone(@Valid @RequestBody VerifyPhoneOtpRequest request, HttpServletRequest httpRequest) {
        UUID userId = CurrentUser.requireUserId(httpRequest);
        return identityService.linkPhone(userId, request.phone(), request.code());
    }

    @Operation(summary = "Is this phone already registered, and does it have a password?", description = """
            Drives the phone sign-in screen: registered + password -> ask for the password; otherwise -> \
            SMS registration. Intentionally reveals registration status (product requirement).""")
    @ApiResponse(responseCode = "200", description = "Status of this phone number")
    @ApiResponse(responseCode = "400", description = "Not a valid, dialable phone number.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/phone/status")
    public PhoneStatusResponse phoneStatus(@Valid @RequestBody PhoneStatusRequest request) {
        return identityService.phoneStatus(request.phone());
    }

    @Operation(summary = "Sign in with phone + password (no SMS)")
    @ApiResponse(responseCode = "200", description = "Signed in")
    @ApiResponse(responseCode = "401", description = "Wrong phone or password.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "429", description = "Too many failed attempts - temporarily locked out.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/phone/login")
    public TokenResponse phoneLogin(@Valid @RequestBody PhonePasswordLoginRequest request) {
        return identityService.loginWithPhonePassword(request.phone(), request.password());
    }

    @Operation(summary = "Register with a phone: SMS code + name + password", description = "Request the code with "
            + "POST /auth/phone/request-otp first. 409 if this phone already has an account.")
    @ApiResponse(responseCode = "200", description = "Account created and signed in")
    @ApiResponse(responseCode = "401", description = "Wrong/already-used code.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "This phone already has an account.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/phone/register")
    public TokenResponse phoneRegister(@Valid @RequestBody PhoneRegisterRequest request) {
        return identityService.registerWithPhone(request.phone(), request.code(), request.displayName(),
                request.password());
    }

    @Operation(summary = "Forgot password: set a new one with an SMS code", description = "Request the code with "
            + "POST /auth/phone/request-otp first. Also sets a first password for an account that has none.")
    @ApiResponse(responseCode = "204", description = "Password changed; other sessions revoked")
    @ApiResponse(responseCode = "401", description = "Wrong/already-used code, or no account for this phone.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/phone/reset-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void phoneResetPassword(@Valid @RequestBody PhoneResetPasswordRequest request) {
        identityService.resetPasswordWithPhone(request.phone(), request.code(), request.newPassword());
    }

    @Operation(summary = "Connect Google/Facebook to the existing account that owns the same email", description = """
            The answer to a 409 ACCOUNT_LINK_REQUIRED from POST /auth/google or /auth/facebook: proves ownership \
            with the existing account's password, then attaches the provider identity to it and signs in.""")
    @ApiResponse(responseCode = "200", description = "Linked and signed in")
    @ApiResponse(responseCode = "401", description = "Wrong password or invalid provider credential.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @PostMapping("/api/v1/auth/identities/link-with-password")
    public TokenResponse linkWithPassword(@Valid @RequestBody LinkWithPasswordRequest request) {
        return identityService.linkProviderWithPassword(request.provider(), request.token(), request.password());
    }
}
