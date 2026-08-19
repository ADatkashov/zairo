package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final CredentialRepository credentialRepository;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public AuthService(UserRepository userRepository, CredentialRepository credentialRepository,
            JwtService jwtService, RefreshTokenService refreshTokenService) {
        this.userRepository = userRepository;
        this.credentialRepository = credentialRepository;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
    }

    @Transactional
    public TokenResponse register(RegisterRequest request) {
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
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));
        Credential credential = credentialRepository.findByUserId(user.getId())
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));

        if (!passwordEncoder.matches(rawPassword, credential.getPasswordHash())) {
            throw new InvalidCredentialsException("Invalid email or password");
        }

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

    private TokenResponse issueTokens(User user) {
        String accessToken = jwtService.issueAccessToken(user.getId(), user.getRole().name());
        String refreshToken = refreshTokenService.issue(user.getId());
        return new TokenResponse(accessToken, refreshToken, toSummary(user));
    }

    private static UserSummary toSummary(User user) {
        return new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole());
    }
}
