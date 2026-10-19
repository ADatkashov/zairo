package com.zairo.factory.auth;

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
 * Validates a customer/business Bearer token and, when it is valid, signs the request in: the
 * principal is the user's id ({@link java.util.UUID}) and the one authority is {@code ROLE_<role>}
 * (e.g. {@code ROLE_ADMIN}). An invalid or missing token leaves the request anonymous — whether that
 * is acceptable is the endpoint's rule (see the platform's {@code EndpointAuthorizationManager}).
 *
 * <p>Not a bean: the platform's {@code SecurityConfig} puts it into the Spring Security filter chain
 * itself, so it runs exactly once and inside the security context's lifecycle.
 */
public class JwtAuthFilter extends OncePerRequestFilter {

    /** Prefix of the customer/business role authorities ({@code ROLE_ADMIN}, {@code ROLE_PROVIDER_OWNER}…). */
    public static final String ROLE_PREFIX = "ROLE_";

    private final JwtService jwtService;
    private final SecurityContextHolderStrategy contextHolder = SecurityContextHolder.getContextHolderStrategy();

    public JwtAuthFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            jwtService.validateAccessToken(header.substring("Bearer ".length())).ifPresent(claims -> {
                SecurityContext context = contextHolder.createEmptyContext();
                context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(claims.userId(), null,
                        List.of(new SimpleGrantedAuthority(ROLE_PREFIX + claims.role()))));
                contextHolder.setContext(context);
            });
        }
        chain.doFilter(request, response);
    }
}
