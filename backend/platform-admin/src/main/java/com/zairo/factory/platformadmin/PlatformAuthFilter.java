package com.zairo.factory.platformadmin;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Mirrors {@code auth.JwtAuthFilter} exactly, on a separate token and a
 * separate pair of request attributes. Runs on every request, same as the
 * customer/business filter — a bearer token that isn't signed with the
 * platform secret simply fails {@code PlatformAdminJwtService.validateAccessToken}
 * and leaves these attributes unset, so the two filters coexist without
 * either one able to satisfy the other's checks.
 */
@Component
class PlatformAuthFilter extends OncePerRequestFilter {

    static final String ADMIN_ID_ATTRIBUTE = "platformAuth.adminId";
    static final String ROLE_ATTRIBUTE = "platformAuth.role";

    private final PlatformAdminJwtService jwtService;

    PlatformAuthFilter(PlatformAdminJwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring("Bearer ".length());
            jwtService.validateAccessToken(token).ifPresent(claims -> {
                request.setAttribute(ADMIN_ID_ATTRIBUTE, claims.adminId());
                request.setAttribute(ROLE_ATTRIBUTE, claims.role());
            });
        }
        chain.doFilter(request, response);
    }
}
