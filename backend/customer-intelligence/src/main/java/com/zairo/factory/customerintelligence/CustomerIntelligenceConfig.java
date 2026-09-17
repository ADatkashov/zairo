package com.zairo.factory.customerintelligence;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Registers {@link CustomerIntelligenceProperties} -- same pattern as {@code smartfill.SmartFillConfig}. */
@Configuration
@EnableConfigurationProperties(CustomerIntelligenceProperties.class)
class CustomerIntelligenceConfig {
}
