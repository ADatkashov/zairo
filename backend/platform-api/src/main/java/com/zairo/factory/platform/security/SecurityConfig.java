package com.zairo.factory.platform.security;

import com.zairo.factory.auth.JwtAuthFilter;
import com.zairo.factory.auth.JwtService;
import com.zairo.factory.platformadmin.PlatformAdminJwtService;
import com.zairo.factory.platformadmin.PlatformAuthFilter;
import jakarta.servlet.DispatcherType;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.AuthorizationFilter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.HandlerExceptionResolver;

/**
 * Spring Security for the stateless JSON API.
 *
 * <ul>
 *   <li>{@code JwtAuthFilter} (customers/businesses) and {@code PlatformAuthFilter} (platform console, its
 *       own secret) sit in this chain: a valid token signs the request in, with {@code ROLE_<role>} or the
 *       platform role's own name as the authority.</li>
 *   <li>{@link EndpointAuthorizationManager} denies by default: an endpoint documented with
 *       {@code @SecurityRequirement} needs authentication, everything else is public.</li>
 *   <li>Role rules live on the endpoints as annotations ({@code @PlatformAdminOnly} and friends,
 *       {@code @PreAuthorize}); ownership rules are moving the same way.</li>
 *   <li>No sessions, no CSRF (bearer tokens are not sent by the browser on their own), no form login.</li>
 *   <li>401/403 are rendered by the app's normal exception advice, so the body is the same
 *       {@code ApiError} JSON as everywhere else.</li>
 *   <li>Security headers; CORS stays in {@code WebConfig}.</li>
 * </ul>
 */
@Configuration
@EnableMethodSecurity
class SecurityConfig {

    /**
     * Sign-in is done by AuthService / PlatformAdminService with their own credentials tables; Spring
     * Security never authenticates a username and password. An explicit empty store stops Boot from
     * creating its default "user" with a random password (which it prints to the log).
     */
    @Bean
    UserDetailsService noPasswordUsers() {
        return new InMemoryUserDetailsManager();
    }

    @Bean
    SecurityFilterChain apiSecurity(HttpSecurity http, EndpointAuthorizationManager endpoints,
            JwtService customerTokens, PlatformAdminJwtService platformTokens,
            @Qualifier("handlerExceptionResolver") HandlerExceptionResolver exceptionResolver) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(Customizer.withDefaults())
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .requestCache(cache -> cache.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .headers(headers -> headers
                        // Cache-Control is set per endpoint (e.g. uploads); don't override it globally.
                        .cacheControl(cache -> cache.disable())
                        .frameOptions(frame -> frame.deny())
                        .referrerPolicy(referrer -> referrer.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER)))
                .addFilterBefore(new JwtAuthFilter(customerTokens), AuthorizationFilter.class)
                .addFilterBefore(new PlatformAuthFilter(platformTokens), AuthorizationFilter.class)
                .authorizeHttpRequests(auth -> auth
                        .dispatcherTypeMatchers(DispatcherType.ERROR, DispatcherType.FORWARD).permitAll()
                        .anyRequest().access(endpoints))
                .exceptionHandling(errors -> errors
                        .authenticationEntryPoint((request, response, ex) -> exceptionResolver.resolveException(request,
                                response, null, new ResponseStatusException(HttpStatus.UNAUTHORIZED,
                                        "Missing or invalid access token")))
                        .accessDeniedHandler((request, response, ex) -> exceptionResolver.resolveException(request,
                                response, null, new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied"))));
        return http.build();
    }
}
