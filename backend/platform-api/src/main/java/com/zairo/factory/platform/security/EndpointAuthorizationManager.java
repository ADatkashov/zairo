package com.zairo.factory.platform.security;

import com.zairo.factory.platformadmin.AnyPlatformRole;
import com.zairo.factory.platformadmin.PlatformAdminOnly;
import com.zairo.factory.platformadmin.PlatformModerationCapable;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import jakarta.servlet.http.HttpServletRequest;
import java.lang.reflect.AnnotatedElement;
import java.util.function.Supplier;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.authorization.AuthorizationDecision;
import org.springframework.security.authorization.AuthorizationManager;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.access.intercept.RequestAuthorizationContext;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerExecutionChain;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

/**
 * Default-deny for every endpoint documented as needing a bearer token
 * ({@code @SecurityRequirement}): without a valid customer/business or platform
 * token Spring Security answers 401 <em>before</em> body validation or any
 * database lookup, instead of leaving each controller to remember it.
 *
 * <p>This only answers "is there a valid token at all"; who the caller is and
 * what they may touch stays with the controllers (ownership, roles) for now.
 * An endpoint without the annotation is public — {@code EndpointAuthPolicyTests}
 * keeps that list explicit, so a new endpoint can't become public by accident.
 */
@Component
public class EndpointAuthorizationManager implements AuthorizationManager<RequestAuthorizationContext> {

    private final RequestMappingHandlerMapping handlerMapping;

    EndpointAuthorizationManager(@Qualifier("requestMappingHandlerMapping") RequestMappingHandlerMapping handlerMapping) {
        this.handlerMapping = handlerMapping;
    }

    @Override
    public AuthorizationDecision authorize(Supplier<? extends Authentication> authentication,
            RequestAuthorizationContext context) {
        if (!requiresAuthentication(handlerFor(context.getRequest()))) {
            return new AuthorizationDecision(true);
        }
        Authentication current = authentication.get();
        boolean authenticated = current != null && current.isAuthenticated()
                && !(current instanceof AnonymousAuthenticationToken);
        if (authenticated && requiresPlatformRole(handlerFor(context.getRequest()))
                && current.getAuthorities().stream().noneMatch(a -> a.getAuthority().startsWith("PLATFORM_"))) {
            // A customer/business token is not a platform credential: on a platform endpoint it counts
            // as no credential at all (401), not as "known but not allowed" (403).
            throw new InsufficientAuthenticationException("A platform access token is required");
        }
        return new AuthorizationDecision(authenticated);
    }

    private HandlerMethod handlerFor(HttpServletRequest request) {
        try {
            HandlerExecutionChain chain = handlerMapping.getHandler(request);
            return chain != null && chain.getHandler() instanceof HandlerMethod method ? method : null;
        } catch (Exception e) {
            // 405/415 and the like: MVC reports them itself, they reveal no data.
            return null;
        }
    }

    private static boolean requiresPlatformRole(HandlerMethod method) {
        return method != null && java.util.stream.Stream.of(PlatformAdminOnly.class, PlatformModerationCapable.class,
                AnyPlatformRole.class).anyMatch(annotation -> AnnotatedElementUtils.hasAnnotation(method.getMethod(),
                        annotation) || AnnotatedElementUtils.hasAnnotation(method.getBeanType(), annotation));
    }

    public static boolean requiresAuthentication(HandlerMethod method) {
        return method != null && (declaresSecurity(method.getMethod()) || declaresSecurity(method.getBeanType()));
    }

    private static boolean declaresSecurity(AnnotatedElement element) {
        return AnnotatedElementUtils.hasAnnotation(element, SecurityRequirement.class)
                || AnnotatedElementUtils.hasAnnotation(element, SecurityRequirements.class);
    }
}
