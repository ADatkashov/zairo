package com.zairo.factory.paymentprovider;

import java.math.BigDecimal;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Always resolves immediately and successfully, synchronously — the local/
 * test default (see {@code payment.provider} in application.yml,
 * conditional on it being {@code mock} or unset). Every call returns
 * {@link PaymentProvider.InitiationStatus#SUCCEEDED} straight away, exactly
 * matching this project's behavior before Freedom Pay existed: no
 * checkout redirect, no webhook wait, nothing for a real caller to poll.
 * This is deliberate, not a shortcut — it's what keeps every booking/
 * subscription test in this codebase passing unmodified under
 * {@code PAYMENT_PROVIDER=mock} (see the Definition of Done in the payment-
 * integration implementation task this was built for).
 */
@Component
@ConditionalOnProperty(name = "payment.provider", havingValue = "mock", matchIfMissing = true)
public class MockPaymentProvider implements PaymentProvider {

    @Override
    public PaymentInitiation createPayment(UUID paymentId, BigDecimal amount, String currency, String description,
            String successUrl, String failureUrl) {
        return new PaymentInitiation("mock_pi_" + paymentId, null, null, InitiationStatus.SUCCEEDED, null);
    }

    @Override
    public PaymentInitiation createRecurringPayment(UUID paymentId, BigDecimal amount, String currency,
            String description, String successUrl, String failureUrl) {
        return new PaymentInitiation("mock_pi_" + paymentId, null, "mock_recurring_" + paymentId,
                InitiationStatus.SUCCEEDED, null);
    }

    @Override
    public ChargeResult chargeRecurring(String recurringProfileId, UUID paymentId, BigDecimal amount,
            String currency) {
        return new ChargeResult(true, "mock_pi_" + paymentId, null);
    }

    @Override
    public PaymentStatusResult getPaymentStatus(UUID paymentId, String providerPaymentId) {
        return new PaymentStatusResult(InitiationStatus.SUCCEEDED, providerPaymentId);
    }

    @Override
    public RefundResult refund(UUID paymentId, String providerPaymentId, BigDecimal amount) {
        return new RefundResult(true, null);
    }
}
