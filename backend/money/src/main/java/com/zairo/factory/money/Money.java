package com.zairo.factory.money;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.math.BigDecimal;
import java.util.Currency;
import java.util.Locale;
import java.util.Objects;

/**
 * An amount that knows its own currency. Embedded (not a separate table)
 * into whichever entity owns it — {@code @AttributeOverride} at each
 * embedding site maps {@link #amount} / {@link #currencyCode} onto that
 * entity's existing column names, so adopting this type doesn't force a
 * column rename anywhere it's already in use.
 *
 * <p>{@code amount} is never negative and never null — every current
 * consumer (a service's price, a booking's total, a payment's charge) is
 * a non-negative quantity; there is no real case today for a negative
 * Money to construct validly. Zero is allowed (a free service is a real,
 * legitimate price). {@code currencyCode} is validated against the real
 * ISO 4217 registry via {@link Currency#getInstance(String)} — no
 * hand-maintained currency list to keep in sync.
 */
@Embeddable
public class Money {

    @Column(name = "amount", nullable = false)
    private BigDecimal amount;

    @Column(name = "currency_code", nullable = false, length = 3)
    private String currencyCode;

    protected Money() {
    }

    public Money(BigDecimal amount, String currencyCode) {
        this.amount = requireNonNegative(amount);
        this.currencyCode = requireValidCurrencyCode(currencyCode);
    }

    public static Money zero(String currencyCode) {
        return new Money(BigDecimal.ZERO, currencyCode);
    }

    private static BigDecimal requireNonNegative(BigDecimal amount) {
        Objects.requireNonNull(amount, "amount must not be null");
        if (amount.signum() < 0) {
            throw new IllegalArgumentException("amount must not be negative: " + amount);
        }
        return amount;
    }

    private static String requireValidCurrencyCode(String currencyCode) {
        Objects.requireNonNull(currencyCode, "currencyCode must not be null");
        // Currency.getInstance requires uppercase input (it does not
        // normalize casing itself) but does validate against the real ISO
        // 4217 registry — uppercase first, then let it validate, so this
        // still accepts "kzt" and rejects genuinely invalid codes.
        try {
            return Currency.getInstance(currencyCode.toUpperCase(Locale.ROOT)).getCurrencyCode();
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Not a valid ISO 4217 currency code: " + currencyCode, e);
        }
    }

    public BigDecimal amount() {
        return amount;
    }

    public String currencyCode() {
        return currencyCode;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof Money money)) {
            return false;
        }
        // BigDecimal.equals considers scale (5.0 != 5.00) — compareTo is
        // the correct notion of "the same amount" for a value type.
        return amount.compareTo(money.amount) == 0 && currencyCode.equals(money.currencyCode);
    }

    @Override
    public int hashCode() {
        return Objects.hash(amount.stripTrailingZeros(), currencyCode);
    }

    @Override
    public String toString() {
        return amount + " " + currencyCode;
    }
}
