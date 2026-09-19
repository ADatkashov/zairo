package com.zairo.factory.payments;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Currency;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Computes ZAIRO's marketplace commission split for a SUCCEEDED payment —
 * see {@code docs/adr/0007-marketplace-commission-and-settlement.md}. A
 * single platform-wide rate ({@code payment.commission.rate}), not a
 * per-booking/per-service/per-business override — this codebase has no
 * product requirement for a variable rate yet (same "don't build for a
 * hypothetical" principle as {@code PaymentsService.createPayment}'s doc
 * comment on deposit-vs-full-payment splitting).
 *
 * <p><b>Rounds the platform fee, derives the business amount by
 * subtraction</b> — never rounds both sides independently. Rounding
 * {@code amount * rate} and {@code amount * (1 - rate)} separately can
 * disagree by the smallest currency unit (e.g. 15000 * 0.10 = 1500.00 but
 * 15000 * 0.90 = 13500.00 — that example happens to agree, but it isn't
 * guaranteed for every amount/rate pair); computing one and subtracting the
 * other from the authoritative total makes {@code businessAmount +
 * platformFee == amount} true by construction, not by coincidence — see
 * {@link PaymentAllocation}'s own constructor, which still asserts it.
 */
@Component
class CommissionCalculator {

    private final BigDecimal rate;

    CommissionCalculator(@Value("${payment.commission.rate:0.10}") BigDecimal rate) {
        if (rate.signum() < 0 || rate.compareTo(BigDecimal.ONE) > 0) {
            // Fail fast at boot — same "don't silently run on a nonsensical
            // config value" reasoning as FreedomPayProvider's api-url check.
            throw new IllegalStateException("payment.commission.rate must be between 0 and 1 (inclusive): " + rate);
        }
        this.rate = rate;
    }

    record Split(BigDecimal businessAmount, BigDecimal platformFee, BigDecimal rate) {
    }

    Split split(BigDecimal amount, String currency) {
        int scale = Currency.getInstance(currency.toUpperCase(Locale.ROOT)).getDefaultFractionDigits();
        BigDecimal platformFee = amount.multiply(rate).setScale(Math.max(scale, 0), RoundingMode.HALF_UP);
        BigDecimal businessAmount = amount.subtract(platformFee);
        return new Split(businessAmount, platformFee, rate);
    }
}
