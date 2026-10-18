package com.zairo.factory.platform.security;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextHolderStrategy;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Bridges the existing token filters ({@code JwtAuthFilter} for customers and
 * businesses, {@code PlatformAuthFilter} for the platform console — both still
 * validate their own JWT and run first) into Spring Security: if either found a
 * valid token, the request gets an authenticated principal here.
 *
 * <p>Authorities: {@code ROLE_<role>} for a customer/business token and
 * {@code PLATFORM_<role>} for a platform one — the two token families stay
 * distinct, so one can never stand in for the other.
 */
final class TokenAuthenticationFilter extends OncePerRequestFilter {

    private final SecurityContextHolderStrategy contextHolder = SecurityContextHolder.getContextHolderStrategy();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        var userId = CurrentUser.optionalUserId(request);
        if (userId.isPresent()) {
            authenticate(userId.get(), "ROLE_" + CurrentUser.requireRole(request));
        } else if (PlatformCurrentAdmin.isAuthenticated(request)) {
            authenticate(PlatformCurrentAdmin.requireAdminId(request),
                    "PLATFORM_" + PlatformCurrentAdmin.requireAnyRole(request).name());
        }
        chain.doFilter(request, response);
    }

    private void authenticate(Object principal, String authority) {
        SecurityContext context = contextHolder.createEmptyContext();
        context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(principal, null,
                List.of(new SimpleGrantedAuthority(authority))));
        contextHolder.setContext(context);
    }
}
