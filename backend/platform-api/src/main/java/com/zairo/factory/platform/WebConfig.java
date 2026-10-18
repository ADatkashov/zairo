package com.zairo.factory.platform;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Origin patterns default to localhost-only — there's no deployed frontend
 * yet, so out of the box this only unblocks `flutter run -d chrome`/local
 * web dev against a local backend. {@code app.cors.allowed-origins} (comma-
 * separated) lets a real deployment add its real domain via env var
 * (CORS_ALLOWED_ORIGINS) instead of a code change — still needs setting
 * before any real deployment, this only removes the need to touch Java to
 * do it.
 */
@Configuration
class WebConfig implements WebMvcConfigurer {

    private final String[] allowedOrigins;

    WebConfig(@Value("${app.cors.allowed-origins:http://localhost:*}") String allowedOrigins) {
        this.allowedOrigins = allowedOrigins.split(",");
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**").allowedOriginPatterns(allowedOrigins).allowedMethods("*").allowedHeaders("*");
    }
}
