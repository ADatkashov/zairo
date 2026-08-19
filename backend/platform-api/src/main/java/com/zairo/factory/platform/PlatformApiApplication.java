package com.zairo.factory.platform;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Modular monolith entrypoint. Scans every bounded-context module
 * ({@code com.zairo.factory.*}) — one deployable JAR, one process.
 */
@SpringBootApplication(scanBasePackages = "com.zairo.factory")
public class PlatformApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(PlatformApiApplication.class, args);
    }
}
