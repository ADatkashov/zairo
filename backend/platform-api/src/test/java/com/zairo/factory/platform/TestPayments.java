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
            public PaymentInitiation createPayment(UUID paymentId, BigDecimal amount, String currency,
                    String description, String successUrl, String failureUrl) {
                return initiate(paymentId, null);
            }

            @Override
            public PaymentInitiation createRecurringPayment(UUID paymentId, BigDecimal amount, String currency,
                    String description, String successUrl, String failureUrl) {
                return initiate(paymentId, "mock_recurring_" + paymentId);
            }

            @Override
            public ChargeResult chargeRecurring(String recurringProfileId, UUID paymentId, BigDecimal amount,
                    String currency) {
                failureController.chargeAttempts.computeIfAbsent(paymentId,
                        id -> new java.util.concurrent.atomic.AtomicInteger()).incrementAndGet();
                if (failureController.failAllRecurringCharges) {
                    return new ChargeResult(false, null, "simulated card decline");
                }
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
            public PaymentStatusResult getPaymentStatus(UUID paymentId, String providerPaymentId) {
                return new PaymentStatusResult(InitiationStatus.SUCCEEDED, providerPaymentId);
            }

            @Override
            public RefundResult refund(UUID paymentId, String providerReference, BigDecimal amount) {
                if (failureController.failNextRefund) {
                    failureController.failNextRefund = false;
                    return new RefundResult(false, "simulated refund outage");
                }
                if (failureController.failRefundTimes.get() > 0) {
                    failureController.failRefundTimes.decrementAndGet();
                    return new RefundResult(false, "simulated refund outage");
                }
                return new RefundResult(true, null);
            }

            /** Shared by createPayment/createRecurringPayment — same failNextCharge/throwOnNextCharge flags chargeRecurring honors. */
            private PaymentInitiation initiate(UUID paymentId, String recurringProfileId) {
                failureController.paymentInitiations.incrementAndGet();
                if (failureController.pendingNextCharge) {
                    failureController.pendingNextCharge = false;
                    return new PaymentInitiation("mock_pending_" + paymentId, "https://pay.test/checkout/" + paymentId,
                            recurringProfileId, InitiationStatus.PENDING, null);
                }
                if (failureController.failNextCharge) {
                    failureController.failNextCharge = false;
                    if (failureController.throwOnNextCharge) {
                        failureController.throwOnNextCharge = false;
                        throw new RuntimeException("simulated provider outage");
                    }
                    return new PaymentInitiation(null, null, null, InitiationStatus.FAILED,
                            "simulated card decline");
                }
                return new PaymentInitiation("mock_pi_" + paymentId, null, recurringProfileId,
                        InitiationStatus.SUCCEEDED, null);
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
        volatile boolean failNextRefund;
        /** The next createPayment/createRecurringPayment is left PENDING with a checkoutUrl, like a redirect-based provider. */
        volatile boolean pendingNextCharge;
        /** How many times a payment was initiated at the provider — proves a repeated request did not start a second one. */
        final java.util.concurrent.atomic.AtomicInteger paymentInitiations = new java.util.concurrent.atomic.AtomicInteger();
        /** Every recurring (renewal) charge is declined while set — unlike failNextCharge, no other subscription in the shared DB can use it up. */
        volatile boolean failAllRecurringCharges;
        /** How many times chargeRecurring was called per charge id — proves a charge was attempted once, not twice. */
        final java.util.concurrent.ConcurrentHashMap<UUID, java.util.concurrent.atomic.AtomicInteger> chargeAttempts =
                new java.util.concurrent.ConcurrentHashMap<>();
        /** Decrementing counter — the next N refund calls fail, then it resolves normally. For PaymentRefundOutboxApiTests. */
        final java.util.concurrent.atomic.AtomicInteger failRefundTimes = new java.util.concurrent.atomic.AtomicInteger();
    }
}
