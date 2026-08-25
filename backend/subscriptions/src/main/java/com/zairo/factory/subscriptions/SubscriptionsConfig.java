package com.zairo.factory.subscriptions;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * The one {@link Clock} bean in this codebase — introduced specifically so
 * {@link SubscriptionRenewalService}'s "is this due" logic is unit-testable
 * with a fixed clock instead of real wall-clock {@code Instant.now()} with
 * relative offsets (the pattern every other time-based test in this project
 * uses). {@code Clock.systemUTC()} in production; tests override this bean
 * (or construct the service directly with {@code Clock.fixed(...)}).
 */
@Configuration
class SubscriptionsConfig {

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }
}
