package com.zairo.factory.auth;

import com.zairo.factory.users.UserRole;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.server.ResponseStatusException;

/**
 * Cross-module entry point for "who is making this request" — reads the Spring Security context that
 * {@link JwtAuthFilter} filled in, so other modules never touch JWTs or Spring Security types. Only a
 * customer/business token counts here: a platform-console token is never a "current user".
 */
public final class CurrentUser {

    private CurrentUser() {
    }

    /** Whether a valid customer/business access token is on the request. Never throws. */
    public static boolean isAuthenticated() {
        return customer() != null;
    }

    /** 401 if there's no valid access token on the request. */
    public static UUID requireUserId() {
        Authentication authentication = customer();
        if (authentication == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
        }
        return (UUID) authentication.getPrincipal();
    }

    /** 401 if there's no valid access token. The role name as stored on the JWT (e.g. "ADMIN"). */
    public static String requireRole() {
        Authentication authentication = customer();
        if (authentication == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
        }
        return authentication.getAuthorities().stream().map(GrantedAuthority::getAuthority)
                .filter(a -> a.startsWith(JwtAuthFilter.ROLE_PREFIX)).findFirst().orElseThrow()
                .substring(JwtAuthFilter.ROLE_PREFIX.length());
    }

    /** 401 if there's no valid access token, 403 if the caller isn't ADMIN. */
    public static void requireAdmin() {
        if (!UserRole.ADMIN.name().equals(requireRole())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin role required");
        }
    }

    /**
     * Empty, never a 401 — for endpoints that don't require auth but still want to know who's asking when
     * a valid token happens to be present. Endpoints that must be authenticated use {@link #requireUserId}.
     */
    public static Optional<UUID> optionalUserId() {
        Authentication authentication = customer();
        return authentication == null ? Optional.empty() : Optional.of((UUID) authentication.getPrincipal());
    }

    private static Authentication customer() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof UUID
                && authentication.getAuthorities().stream()
                        .anyMatch(a -> a.getAuthority().startsWith(JwtAuthFilter.ROLE_PREFIX))) {
            return authentication;
        }
        return null;
    }
}
