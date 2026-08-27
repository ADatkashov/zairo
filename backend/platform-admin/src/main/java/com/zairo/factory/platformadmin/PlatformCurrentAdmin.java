package com.zairo.factory.platformadmin;

import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Mirrors {@code auth.CurrentUser}'s shape — reads what
 * {@link PlatformAuthFilter} already populated, so controllers never touch
 * the request-attribute names or JWT validation directly.
 */
public final class PlatformCurrentAdmin {

    private PlatformCurrentAdmin() {
    }

    /** 401 if there's no valid platform access token on the request. */
    public static UUID requireAdminId(HttpServletRequest request) {
        Object value = request.getAttribute(PlatformAuthFilter.ADMIN_ID_ATTRIBUTE);
        if (value instanceof UUID adminId) {
            return adminId;
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid platform access token");
    }

    /** 401 if there's no valid platform access token. Any authenticated platform role — PLATFORM_ADMIN or PLATFORM_SUPPORT. */
    public static PlatformRole requireAnyRole(HttpServletRequest request) {
        Object value = request.getAttribute(PlatformAuthFilter.ROLE_ATTRIBUTE);
        if (value instanceof String role) {
            try {
                return PlatformRole.valueOf(role);
            } catch (IllegalArgumentException ignored) {
                // falls through to the same 401 as "no role at all"
            }
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid platform access token");
    }

    /** 401 if unauthenticated, 403 if authenticated but not PLATFORM_ADMIN — the only mutation-capable role. */
    public static void requirePlatformAdmin(HttpServletRequest request) {
        if (requireAnyRole(request) != PlatformRole.PLATFORM_ADMIN) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "PLATFORM_ADMIN role required");
        }
    }
}
