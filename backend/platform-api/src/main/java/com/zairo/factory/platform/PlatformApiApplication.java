package com.zairo.factory.platform;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.persistence.autoconfigure.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Modular monolith entrypoint. Scans every bounded-context module
 * ({@code com.zairo.factory.*}) — one deployable JAR, one process.
 *
 * {@code @EntityScan}/{@code @EnableJpaRepositories} are needed alongside
 * {@code scanBasePackages}: Spring Data JPA's auto-configuration only infers
 * a base package from this class's own package ({@code ...platform}) by
 * default, which doesn't cover sibling module packages like
 * {@code com.zairo.factory.users}.
 *
 * <p>{@code @EnableScheduling} exists solely for
 * {@code subscriptions.SubscriptionRenewalJob} — see the subscriptions ADR
 * for why this project's first {@code @Scheduled} job was worth the new
 * infrastructure. Not a general-purpose invitation to add more background
 * jobs without the same justification.
 */
@SpringBootApplication(scanBasePackages = "com.zairo.factory")
@EntityScan(basePackages = "com.zairo.factory")
@EnableJpaRepositories(basePackages = "com.zairo.factory")
@EnableScheduling
public class PlatformApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(PlatformApiApplication.class, args);
    }
}
