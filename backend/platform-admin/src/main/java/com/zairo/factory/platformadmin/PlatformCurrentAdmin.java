package com.zairo.factory.platformadmin;

import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.server.ResponseStatusException;

/**
 * Mirrors {@code auth.CurrentUser}'s shape — reads the Spring Security context that
 * {@link PlatformAuthFilter} filled in, so controllers never touch JWTs or Spring Security types. Only a
 * platform-console token counts here: a customer/business token is never a "current admin".
 *
 */
public final class PlatformCurrentAdmin {

    private PlatformCurrentAdmin() {
    }

    /** Whether the request carries a valid platform access token. Never throws. */
    public static boolean isAuthenticated() {
        return platform() != null;
    }

    /** 401 if there's no valid platform access token on the request. */
    public static UUID requireAdminId() {
        Authentication authentication = platform();
        if (authentication == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid platform access token");
        }
        return (UUID) authentication.getPrincipal();
    }

    /** 401 if there's no valid platform access token. Any authenticated platform role. */
    public static PlatformRole requireAnyRole() {
        Authentication authentication = platform();
        if (authentication == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid platform access token");
        }
        return authentication.getAuthorities().stream().map(GrantedAuthority::getAuthority)
                .map(PlatformCurrentAdmin::roleOrNull).filter(java.util.Objects::nonNull).findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED,
                        "Missing or invalid platform access token"));
    }

    private static PlatformRole roleOrNull(String authority) {
        try {
            return PlatformRole.valueOf(authority);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static Authentication platform() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof UUID
                && authentication.getAuthorities().stream().anyMatch(a -> roleOrNull(a.getAuthority()) != null)) {
            return authentication;
        }
        return null;
    }

    /** 401 if unauthenticated, 403 if authenticated but not PLATFORM_ADMIN — the only mutation-capable role. */
    public static void requirePlatformAdmin() {
        if (requireAnyRole() != PlatformRole.PLATFORM_ADMIN) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "PLATFORM_ADMIN role required");
        }
    }

    /**
     * 401 if unauthenticated, 403 if PLATFORM_SUPPORT (read-only) — business
     * moderation (approve/suspend/reinstate a provider) is the one mutation
     * PLATFORM_MODERATOR can also perform, alongside PLATFORM_ADMIN.
     */
    public static void requireModerationCapable() {
        PlatformRole role = requireAnyRole();
        if (role != PlatformRole.PLATFORM_ADMIN && role != PlatformRole.PLATFORM_MODERATOR) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "PLATFORM_ADMIN or PLATFORM_MODERATOR role required");
        }
    }
}
