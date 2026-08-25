package com.zairo.factory.platform;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Substitutes a controllable clock for the real {@code Clock.systemUTC()}
 * (see {@code subscriptions.SubscriptionsConfig}) so renewal/grace-period
 * tests can deterministically jump time forward instead of waiting on real
 * wall-clock time or computing fragile relative offsets — same "shared
 * test-support helper overriding a real bean via @Primary" convention as
 * {@link TestPayments}.
 */
@TestConfiguration(proxyBeanMethods = false)
class TestClock {

    @Bean
    @Primary
    MutableClock testClock() {
        return new MutableClock(Instant.now(), ZoneOffset.UTC);
    }

    static final class MutableClock extends Clock {
        private final AtomicReference<Instant> instant;
        private final ZoneId zone;

        MutableClock(Instant initial, ZoneId zone) {
            this.instant = new AtomicReference<>(initial);
            this.zone = zone;
        }

        void advanceTo(Instant newInstant) {
            instant.set(newInstant);
        }

        @Override
        public ZoneId getZone() {
            return zone;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return new MutableClock(instant.get(), zone);
        }

        @Override
        public Instant instant() {
            return instant.get();
        }
    }
}
