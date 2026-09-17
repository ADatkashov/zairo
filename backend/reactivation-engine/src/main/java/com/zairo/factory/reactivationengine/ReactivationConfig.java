package com.zairo.factory.reactivationengine;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Registers {@link ReactivationProperties} -- same pattern as {@code rebookengine.RebookConfig}. */
@Configuration
@EnableConfigurationProperties(ReactivationProperties.class)
class ReactivationConfig {
}
