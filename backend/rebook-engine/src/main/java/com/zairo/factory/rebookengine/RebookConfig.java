package com.zairo.factory.rebookengine;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Registers {@link RebookProperties} -- same pattern as {@code smartfill.SmartFillConfig}. */
@Configuration
@EnableConfigurationProperties(RebookProperties.class)
class RebookConfig {
}
