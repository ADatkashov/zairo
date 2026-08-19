package com.zairo.factory.platform;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Permissive CORS for localhost only — there's no deployed frontend yet, so
 * this only unblocks `flutter run -d chrome`/local web dev against a local
 * backend. Tighten to specific origins before any real deployment.
 */
@Configuration
class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**").allowedOriginPatterns("http://localhost:*").allowedMethods("*")
                .allowedHeaders("*");
    }
}
