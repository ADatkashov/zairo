package com.zairo.factory.platformadmin;

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
 * Validates a platform-console Bearer token (its own signing secret) and, when valid, signs the request
 * in: principal = the admin's id, one authority = the role's own name ({@code PLATFORM_ADMIN},
 * {@code PLATFORM_MODERATOR}, {@code PLATFORM_SUPPORT}). A customer/business token fails this secret and
 * leaves the request unauthenticated here, and the reverse holds for {@code JwtAuthFilter}: the two token
 * families can never stand in for each other.
 *
 * <p>Not a bean: the platform's {@code SecurityConfig} puts it into the filter chain itself.
 */
public class PlatformAuthFilter extends OncePerRequestFilter {

    private final PlatformAdminJwtService jwtService;
    private final SecurityContextHolderStrategy contextHolder = SecurityContextHolder.getContextHolderStrategy();

    public PlatformAuthFilter(PlatformAdminJwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            jwtService.validateAccessToken(header.substring("Bearer ".length())).ifPresent(claims -> {
                SecurityContext context = contextHolder.createEmptyContext();
                context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(claims.adminId(), null,
                        List.of(new SimpleGrantedAuthority(claims.role()))));
                contextHolder.setContext(context);
            });
        }
        chain.doFilter(request, response);
    }
}
