package com.zairo.factory.platform;

import com.zairo.factory.paymentprovider.PaymentProvider;
import java.math.BigDecimal;
import java.util.UUID;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Substitutes a controllable fake for the real (always-succeeds)
 * MockPaymentProvider so tests can simulate a declined charge or a
 * provider-side exception (network error) on demand — the real
 * MockPaymentProvider bean can't do either, so tests proving
 * PaymentsService's failure/idempotency handling need this instead. Same
 * "shared test-support helper" convention as TestAuth/TestNotifications.
 */
@TestConfiguration(proxyBeanMethods = false)
class TestPayments {

    @Bean
    @Primary
    PaymentProvider testPaymentProvider(FailureController failureController) {
        return new PaymentProvider() {
            @Override
            public ChargeResult charge(UUID paymentId, BigDecimal amount, String currency) {
                if (failureController.failNextCharge) {
                    failureController.failNextCharge = false;
                    if (failureController.throwOnNextCharge) {
                        failureController.throwOnNextCharge = false;
                        throw new RuntimeException("simulated provider outage");
                    }
                    return new ChargeResult(false, null, "simulated card decline");
                }
                return new ChargeResult(true, "mock_pi_" + paymentId, null);
            }

            @Override
            public RefundResult refund(UUID paymentId, String providerReference, BigDecimal amount) {
                return new RefundResult(true, null);
            }
        };
    }

    @Bean
    FailureController failureController() {
        return new FailureController();
    }

    /** A real Spring bean (not a static field) so it resets per test context, not per JVM. */
    static class FailureController {
        volatile boolean failNextCharge;
        volatile boolean throwOnNextCharge;
    }
}
