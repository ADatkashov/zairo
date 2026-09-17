package com.zairo.factory.smartfill;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Registers {@link SmartFillProperties} -- same pattern as {@code paymentprovider.freedompay.FreedomPayConfig}. */
@Configuration
@EnableConfigurationProperties(SmartFillProperties.class)
class SmartFillConfig {
}
