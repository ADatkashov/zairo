package com.zairo.factory.platform.openapi;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * The server list Swagger UI's environment picker shows — bound from
 * {@code app.openapi.servers} in application.yml rather than hardcoded here,
 * so adding a Test/Production entry later is a config change, not a code
 * change. Only "Local" exists today (see application.yml) — this project
 * has no deployed environment yet.
 */
@ConfigurationProperties(prefix = "app.openapi")
public record OpenApiProperties(List<ServerEntry> servers) {

    public record ServerEntry(String url, String description) {
    }
}
