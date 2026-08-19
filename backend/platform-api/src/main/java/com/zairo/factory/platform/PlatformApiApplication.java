package com.zairo.factory.platform;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.persistence.autoconfigure.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * Modular monolith entrypoint. Scans every bounded-context module
 * ({@code com.zairo.factory.*}) — one deployable JAR, one process.
 *
 * {@code @EntityScan}/{@code @EnableJpaRepositories} are needed alongside
 * {@code scanBasePackages}: Spring Data JPA's auto-configuration only infers
 * a base package from this class's own package ({@code ...platform}) by
 * default, which doesn't cover sibling module packages like
 * {@code com.zairo.factory.users}.
 */
@SpringBootApplication(scanBasePackages = "com.zairo.factory")
@EntityScan(basePackages = "com.zairo.factory")
@EnableJpaRepositories(basePackages = "com.zairo.factory")
public class PlatformApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(PlatformApiApplication.class, args);
    }
}
