package com.zairo.factory.payments;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Currency;
import java.util.Locale;

/**
 * Computes ZAIRO's marketplace commission split for a SUCCEEDED payment —
 * see {@code docs/adr/0007-marketplace-commission-and-settlement.md}. The
 * rate itself is not decided here: {@link CommissionRateService} resolves
 * it per booking (category override, else the platform default, 0% until a
 * PLATFORM_ADMIN sets one) and this class only turns a rate into a split.
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
final class CommissionCalculator {

    private CommissionCalculator() {
    }

    record Split(BigDecimal businessAmount, BigDecimal platformFee, BigDecimal rate) {
    }

    static Split split(BigDecimal amount, String currency, BigDecimal rate) {
        if (rate.signum() < 0 || rate.compareTo(BigDecimal.ONE) > 0) {
            throw new IllegalArgumentException("commission rate must be between 0 and 1 (inclusive): " + rate);
        }
        int scale = Currency.getInstance(currency.toUpperCase(Locale.ROOT)).getDefaultFractionDigits();
        BigDecimal platformFee = amount.multiply(rate).setScale(Math.max(scale, 0), RoundingMode.HALF_UP);
        BigDecimal businessAmount = amount.subtract(platformFee);
        return new Split(businessAmount, platformFee, rate);
    }
}
