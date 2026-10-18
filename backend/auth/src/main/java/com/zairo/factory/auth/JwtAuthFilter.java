package com.zairo.factory.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Not a global "protect everything" gate — this only populates
 * request attributes when a valid Bearer token is present. Endpoints that
 * require auth check for the attribute themselves (see AuthController.me)
 * and reject with 401 if missing; endpoints that don't require auth (e.g.
 * search/browse) are unaffected either way. A real access-control policy
 * (which endpoints require which role) is a decision for whenever the app
 * has enough protected endpoints to need one, not a single-endpoint MVP.
 */
// Runs before the Spring Security filter chain (order -100) so the chain sees who the caller is.
@Order(-110)
@Component
class JwtAuthFilter extends OncePerRequestFilter {

    static final String USER_ID_ATTRIBUTE = "auth.userId";
    static final String ROLE_ATTRIBUTE = "auth.role";

    private final JwtService jwtService;

    JwtAuthFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring("Bearer ".length());
            jwtService.validateAccessToken(token).ifPresent(claims -> {
                request.setAttribute(USER_ID_ATTRIBUTE, claims.userId());
                request.setAttribute(ROLE_ATTRIBUTE, claims.role());
            });
        }
        chain.doFilter(request, response);
    }
}
