package com.zairo.factory.auth;

import jakarta.servlet.http.HttpServletRequest;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Cross-module entry point for "who is making this request" — reads what
 * {@link JwtAuthFilter} already populated on the request, without other
 * modules needing to know the attribute name or touch JWT validation
 * themselves. Bounded-context modules that need to enforce "only the owner
 * can do this" (see e.g. services/booking/vertical-beauty's update/delete
 * endpoints) depend on this module for exactly this one class.
 */
public final class CurrentUser {

    private CurrentUser() {
    }

    /** 401 if there's no valid access token on the request. */
    public static UUID requireUserId(HttpServletRequest request) {
        Object value = request.getAttribute(JwtAuthFilter.USER_ID_ATTRIBUTE);
        if (value instanceof UUID userId) {
            return userId;
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
    }
}
