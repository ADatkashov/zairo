package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.LoginRequest;
import com.zairo.factory.auth.AuthDtos.RefreshRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class AuthController {

    private final AuthService authService;
    private final UserRepository userRepository;

    public AuthController(AuthService authService, UserRepository userRepository) {
        this.authService = authService;
        this.userRepository = userRepository;
    }

    @PostMapping("/api/v1/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse register(@RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/api/v1/auth/login")
    public TokenResponse login(@RequestBody LoginRequest request) {
        return authService.login(request.email(), request.password());
    }

    @PostMapping("/api/v1/auth/refresh")
    public TokenResponse refresh(@RequestBody RefreshRequest request) {
        return authService.refresh(request.refreshToken());
    }

    @GetMapping("/api/v1/auth/me")
    public UserSummary me(HttpServletRequest request) {
        UUID userId = (UUID) request.getAttribute(JwtAuthFilter.USER_ID_ATTRIBUTE);
        if (userId == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User no longer exists"));
        return new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole());
    }
}
