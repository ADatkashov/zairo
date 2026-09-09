package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.users.UserRole;
import java.time.Instant;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final CredentialRepository credentialRepository;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final PasswordResetTokenService passwordResetTokenService;
    private final ApplicationEventPublisher eventPublisher;
    private final LoginAttemptLimiter loginAttemptLimiter;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public AuthService(UserRepository userRepository, CredentialRepository credentialRepository,
            JwtService jwtService, RefreshTokenService refreshTokenService,
            PasswordResetTokenService passwordResetTokenService, ApplicationEventPublisher eventPublisher,
            LoginAttemptLimiter loginAttemptLimiter) {
        this.userRepository = userRepository;
        this.credentialRepository = credentialRepository;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.passwordResetTokenService = passwordResetTokenService;
        this.eventPublisher = eventPublisher;
        this.loginAttemptLimiter = loginAttemptLimiter;
    }

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        // ADMIN is never self-assignable through the public API — an account
        // that can moderate other owners' providers must be granted directly
        // in the database, not claimed by anyone who can call this endpoint.
        if (request.role() == UserRole.ADMIN) {
            throw new AdminRoleNotSelfAssignableException("Cannot self-register with the ADMIN role");
        }
        if (userRepository.findByEmail(request.email()).isPresent()) {
            throw new EmailAlreadyRegisteredException("Email already registered: " + request.email());
        }

        User user = new User(UUID.randomUUID(), request.email(), request.phone(), request.displayName(),
                request.role(), Instant.now());
        user = userRepository.save(user);

        Credential credential = new Credential(UUID.randomUUID(), user.getId(),
                passwordEncoder.encode(request.password()), Instant.now());
        credentialRepository.save(credential);

        return issueTokens(user);
    }

    @Transactional
    public TokenResponse login(String email, String rawPassword) {
        loginAttemptLimiter.checkNotLockedOut(email);

        User user = userRepository.findByEmail(email).orElse(null);
        Credential credential = user == null ? null : credentialRepository.findByUserId(user.getId()).orElse(null);
        if (user == null || credential == null || !passwordEncoder.matches(rawPassword, credential.getPasswordHash())) {
            loginAttemptLimiter.recordFailure(email);
            throw new InvalidCredentialsException("Invalid email or password");
        }

        loginAttemptLimiter.recordSuccess(email);
        return issueTokens(user);
    }

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        RefreshTokenService.RotatedToken rotated = refreshTokenService.rotate(rawRefreshToken);
        User user = userRepository.findById(rotated.userId())
                .orElseThrow(() -> new InvalidRefreshTokenException("User for refresh token no longer exists"));
        String accessToken = jwtService.issueAccessToken(user.getId(), user.getRole().name());
        return new TokenResponse(accessToken, rotated.rawToken(), toSummary(user));
    }

    /**
     * Always returns normally, whether or not the email belongs to a real
     * account — a different response (or timing) would let a caller probe
     * which emails are registered. If a user is found, a reset code is
     * generated and "emailed" (see NotificationService/EmailNotificationProvider).
     */
    @Transactional
    public void forgotPassword(String email) {
        userRepository.findByEmail(email).ifPresent(user -> {
            String rawToken = passwordResetTokenService.issue(user.getId());
            eventPublisher.publishEvent(new PasswordResetRequestedEvent(user.getId(), user.getEmail(), rawToken));
        });
    }

    /**
     * Consumes the reset token (single-use, see PasswordResetTokenService),
     * re-hashes the new password through the same BCrypt encoder every
     * other password goes through, and revokes existing sessions on other
     * devices — same reasoning as changing a password anywhere else.
     */
    @Transactional
    public void resetPassword(String rawToken, String newPassword) {
        UUID userId = passwordResetTokenService.consume(rawToken);
        Credential credential = credentialRepository.findByUserId(userId)
                .orElseThrow(() -> new InvalidPasswordResetTokenException("No credentials for this account"));
        credential.changePasswordHash(passwordEncoder.encode(newPassword));
        credentialRepository.save(credential);
        refreshTokenService.revokeAllForUser(userId);
    }

    private TokenResponse issueTokens(User user) {
        String accessToken = jwtService.issueAccessToken(user.getId(), user.getRole().name());
        String refreshToken = refreshTokenService.issue(user.getId());
        return new TokenResponse(accessToken, refreshToken, toSummary(user));
    }

    /**
     * Same owner-writes-their-own-account shape as resetPassword: no
     * ownership check needed beyond "this is the caller's own user id",
     * which CurrentUser.requireUserId already guarantees at the controller.
     */
    @Transactional
    public UserSummary updateAvatar(UUID userId, String avatarUrl) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User no longer exists"));
        user.updateAvatar(avatarUrl);
        userRepository.save(user);
        return toSummary(user);
    }

    private static UserSummary toSummary(User user) {
        return new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole(),
                user.getAvatarUrl());
    }
}
