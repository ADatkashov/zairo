package com.zairo.factory.money;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class MoneyTest {

    @Test
    void exposesTheAmountAndNormalizedCurrencyCode() {
        Money money = new Money(new BigDecimal("15000.50"), "kzt");

        assertEquals(new BigDecimal("15000.50"), money.amount());
        // Currency.getInstance normalizes casing.
        assertEquals("KZT", money.currencyCode());
    }

    @Test
    void zeroIsAValidAmount() {
        Money money = Money.zero("USD");

        assertEquals(0, money.amount().signum());
    }

    @Test
    void rejectsANegativeAmount() {
        assertThrows(IllegalArgumentException.class, () -> new Money(new BigDecimal("-1"), "USD"));
    }

    @Test
    void rejectsANullAmount() {
        assertThrows(NullPointerException.class, () -> new Money(null, "USD"));
    }

    @Test
    void rejectsANullCurrencyCode() {
        assertThrows(NullPointerException.class, () -> new Money(BigDecimal.TEN, null));
    }

    @Test
    void rejectsACurrencyCodeThatIsNotRealIso4217() {
        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> new Money(BigDecimal.TEN, "XYZ"));
        assertEquals("Not a valid ISO 4217 currency code: XYZ", exception.getMessage());
    }

    @Test
    void equalityComparesAmountByValueNotByScale() {
        // 5.0 and 5.00 are different BigDecimal.equals() values but the
        // same amount of money.
        assertEquals(new Money(new BigDecimal("5.0"), "USD"), new Money(new BigDecimal("5.00"), "USD"));
        assertEquals(
                new Money(new BigDecimal("5.0"), "USD").hashCode(),
                new Money(new BigDecimal("5.00"), "USD").hashCode());
    }

    @Test
    void differentCurrenciesAreNeverEqualEvenWithTheSameAmount() {
        assertNotEquals(new Money(BigDecimal.TEN, "USD"), new Money(BigDecimal.TEN, "EUR"));
    }
}
