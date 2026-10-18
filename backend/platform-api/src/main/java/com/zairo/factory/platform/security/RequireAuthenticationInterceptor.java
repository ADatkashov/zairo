package com.zairo.factory.platform.security;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Default-deny for every endpoint documented as needing a bearer token
 * ({@code @SecurityRequirement}): without a valid customer/business or
 * platform token the request is rejected with 401 <em>before</em> body
 * validation or any database lookup, instead of leaving each controller to
 * remember it (which used to answer an anonymous caller 400/404 first).
 *
 * <p>This only answers "is there a valid token at all"; who the caller is
 * and what they may touch stays with the controllers (ownership, roles).
 * An endpoint without the annotation is public — {@code EndpointAuthPolicyTests}
 * keeps that list explicit, so a new endpoint can't become public by accident.
 */
@Component
public class RequireAuthenticationInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (handler instanceof HandlerMethod method && requiresAuthentication(method)
                && !CurrentUser.isAuthenticated(request) && !PlatformCurrentAdmin.isAuthenticated(request)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing or invalid access token");
        }
        return true;
    }

    public static boolean requiresAuthentication(HandlerMethod method) {
        return declaresSecurity(method.getMethod()) || declaresSecurity(method.getBeanType());
    }

    private static boolean declaresSecurity(java.lang.reflect.AnnotatedElement element) {
        return AnnotatedElementUtils.hasAnnotation(element, SecurityRequirement.class)
                || AnnotatedElementUtils.hasAnnotation(element, SecurityRequirements.class);
    }
}
