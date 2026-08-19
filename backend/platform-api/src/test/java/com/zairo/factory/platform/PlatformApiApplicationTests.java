package com.zairo.factory.platform;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

/**
 * Verifies that every bounded-context module wires together into one
 * Spring context, against a real Postgres (Testcontainers) — the real test
 * of a modular monolith skeleton with a real datasource/Flyway migration.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
class PlatformApiApplicationTests {

    @Test
    void contextLoads() {
    }
}
