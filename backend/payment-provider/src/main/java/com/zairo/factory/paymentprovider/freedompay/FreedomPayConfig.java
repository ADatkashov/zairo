package com.zairo.factory.paymentprovider.freedompay;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/** Registers {@link FreedomPayProperties} — same pattern as {@code storage.StorageConfig}. */
@Configuration
@EnableConfigurationProperties(FreedomPayProperties.class)
class FreedomPayConfig {
}
