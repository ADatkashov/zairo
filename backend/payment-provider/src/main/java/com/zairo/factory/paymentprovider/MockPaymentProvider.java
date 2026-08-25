package com.zairo.factory.paymentprovider;

import java.math.BigDecimal;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Always succeeds immediately — stands in for Stripe (or similar) until
 * this project has a real provider account and API keys. Replace with a
 * real {@link PaymentProvider} implementation (e.g. backed by
 * stripe-java's PaymentIntent/Refund APIs) behind a Spring profile or
 * conditional bean once those credentials exist; nothing else in either
 * caller module ({@code payments}, {@code subscriptions}) should need to
 * change.
 */
@Component
public class MockPaymentProvider implements PaymentProvider {

    @Override
    public ChargeResult charge(UUID paymentId, BigDecimal amount, String currency) {
        return new ChargeResult(true, "mock_pi_" + paymentId, null);
    }

    @Override
    public RefundResult refund(UUID paymentId, String providerReference, BigDecimal amount) {
        return new RefundResult(true, null);
    }
}
