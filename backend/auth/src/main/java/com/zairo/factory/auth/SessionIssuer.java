package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.users.User;
import org.springframework.stereotype.Component;

/**
 * Turns a {@link User} row into a fresh ZAIRO session — the one thing every
 * login path (password, Google, Facebook, phone OTP, token refresh) ends
 * with. Pulled out of AuthService (where this used to be a private method)
 * so IdentityService can issue the exact same kind of session without a
 * second, parallel implementation — see CLAUDE.md task spec's "Не создавай
 * второй параллельный authentication механизм."
 */
@Component
class SessionIssuer {

    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;

    SessionIssuer(JwtService jwtService, RefreshTokenService refreshTokenService) {
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
    }

    TokenResponse issue(User user) {
        String accessToken = jwtService.issueAccessToken(user.getId(), user.getRole().name());
        String refreshToken = refreshTokenService.issue(user.getId());
        return new TokenResponse(accessToken, refreshToken, toSummary(user));
    }

    static UserSummary toSummary(User user) {
        return new UserSummary(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole(),
                user.getAvatarUrl());
    }
}
