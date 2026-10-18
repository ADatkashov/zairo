package com.zairo.factory.auth;

import com.zairo.factory.users.UserRole;
import jakarta.servlet.http.HttpServletRequest;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Cross-module entry point for "who is making this request" — reads what
 * {@link JwtAuthFilter} already populated on the request, without other
 * modules needing to know the attribute name or touch JWT validation
 * themselves. Bounded-context modules that need to enforce "only the owner
 * can do this" (see e.g. services/booking/vertical-beauty/vertical-auto's
 * update/delete endpoints) depend on this module for exactly this one
 * class.
 */
public final class CurrentUser {

    private CurrentUser() {
    }

    /** Whether the request carries a valid customer/business access token. Never throws. */
    public static boolean isAuthenticated(HttpServletRequest request) {
        return request.getAttribute(JwtAuthFilter.USER_ID_ATTRIBUTE) instanceof UUID;
    }

    /** 401 if there's no valid access token on the request. */
    public static UUID requireUserId(HttpServletRequest request) {
        Object value = request.getAttribute(JwtAuthFilter.USER_ID_ATTRIBUTE);
        if (value instanceof UUID userId) {
            return userId;
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
    }

    /** 401 if there's no valid access token on the request. The role name as stored on the JWT (e.g. "ADMIN"). */
    public static String requireRole(HttpServletRequest request) {
        Object value = request.getAttribute(JwtAuthFilter.ROLE_ATTRIBUTE);
        if (value instanceof String role) {
            return role;
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
    }

    /** 401 if there's no valid access token, 403 if the caller isn't ADMIN. */
    public static void requireAdmin(HttpServletRequest request) {
        if (!UserRole.ADMIN.name().equals(requireRole(request))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin role required");
        }
    }

    /**
     * Empty, never a 401 — for endpoints that don't require auth but still
     * want to know who's asking when a valid token happens to be present
     * (e.g. an anonymous-friendly view event). Endpoints that must be
     * authenticated should keep using {@link #requireUserId}.
     */
    public static Optional<UUID> optionalUserId(HttpServletRequest request) {
        Object value = request.getAttribute(JwtAuthFilter.USER_ID_ATTRIBUTE);
        return value instanceof UUID userId ? Optional.of(userId) : Optional.empty();
    }
}
