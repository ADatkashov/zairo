package com.zairo.factory.booking;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.depositpolicy.DepositType;
import com.zairo.factory.depositpolicy.DepositValueType;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Plain unit test of the Booking aggregate -- no Spring context, no database. */
class BookingTest {

    private static final Instant NOW = Instant.parse("2026-10-12T10:00:00Z");

    private static Booking booking(DepositType type, String total, String depositAmount) {
        return new Booking(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                BookingStatus.PENDING_PAYMENT, new BigDecimal(total), "KZT", NOW, type,
                type == DepositType.DEPOSIT ? DepositValueType.FIXED_AMOUNT : null, null,
                depositAmount == null ? null : new BigDecimal(depositAmount));
    }

    private static BigDecimal bd(String v) {
        return new BigDecimal(v);
    }

    @Test
    void newBookingOwesTheWholePriceAndHasPaidNothing() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);

        assertThat(b.getPaidAmount()).isEqualByComparingTo("0");
        assertThat(b.getRemainingAmount()).isEqualByComparingTo("10000");
        assertThat(b.getCurrency()).isEqualTo("KZT");
        assertThat(b.getCancellationReason()).isNull();
    }

    @Test
    void recordPaymentReducesRemainingAndAccumulates() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);

        b.recordPayment(bd("3000"));
        b.recordPayment(bd("2000"));

        assertThat(b.getPaidAmount()).isEqualByComparingTo("5000");
        assertThat(b.getRemainingAmount()).isEqualByComparingTo("5000");
        assertThat(b.isFullyPaid()).isFalse();
    }

    @Test
    void recordPaymentIgnoresNullZeroAndNegativeAmounts() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);

        b.recordPayment(null);
        b.recordPayment(BigDecimal.ZERO);
        b.recordPayment(bd("-500"));

        assertThat(b.getPaidAmount()).isEqualByComparingTo("0");
        assertThat(b.getRemainingAmount()).isEqualByComparingTo("10000");
    }

    @Test
    void bookingIsFullyPaidOnlyOnceTheWholePriceIsRecorded() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);

        b.recordPayment(bd("9999"));
        assertThat(b.isFullyPaid()).isFalse();

        b.recordPayment(bd("1"));
        assertThat(b.isFullyPaid()).isTrue();
    }

    @Test
    void recordRefundGivesMoneyBackButNeverGoesBelowZero() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);
        b.recordPayment(bd("4000"));

        b.recordRefund(bd("1500"));
        assertThat(b.getPaidAmount()).isEqualByComparingTo("2500");
        assertThat(b.getRemainingAmount()).isEqualByComparingTo("7500");

        b.recordRefund(bd("99999"));
        assertThat(b.getPaidAmount()).isEqualByComparingTo("0");
        assertThat(b.getRemainingAmount()).isEqualByComparingTo("10000");
    }

    @Test
    void recordRefundIgnoresNullZeroAndNegativeAmounts() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);
        b.recordPayment(bd("4000"));

        b.recordRefund(null);
        b.recordRefund(BigDecimal.ZERO);
        b.recordRefund(bd("-100"));

        assertThat(b.getPaidAmount()).isEqualByComparingTo("4000");
    }

    @Test
    void noPaymentBookingCountsAsDepositPaidImmediately() {
        assertThat(booking(DepositType.NO_PAYMENT, "10000", null).hasDepositBeenPaid()).isTrue();
    }

    @Test
    void fullPaymentBookingNeedsTheWholePrice() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);

        b.recordPayment(bd("9000"));
        assertThat(b.hasDepositBeenPaid()).isFalse();

        b.recordPayment(bd("1000"));
        assertThat(b.hasDepositBeenPaid()).isTrue();
    }

    @Test
    void depositBookingNeedsOnlyTheDepositAmount() {
        Booking b = booking(DepositType.DEPOSIT, "10000", "3000");

        b.recordPayment(bd("2999"));
        assertThat(b.hasDepositBeenPaid()).isFalse();

        b.recordPayment(bd("1"));
        assertThat(b.hasDepositBeenPaid()).isTrue();
        assertThat(b.isFullyPaid()).isFalse();
    }

    @Test
    void reduceTotalPriceLowersTotalAndRemaining() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);

        b.reduceTotalPrice(bd("8000"));

        assertThat(b.getTotalPrice()).isEqualByComparingTo("8000");
        assertThat(b.getRemainingAmount()).isEqualByComparingTo("8000");
        assertThat(b.getCurrency()).isEqualTo("KZT");
    }

    @Test
    void reduceTotalPriceCapsTheDepositAtTheNewTotal() {
        Booking b = booking(DepositType.DEPOSIT, "10000", "6000");

        b.reduceTotalPrice(bd("5000"));

        assertThat(b.getDepositAmount()).isEqualByComparingTo("5000");
    }

    @Test
    void reduceTotalPriceNeverLeavesNegativeRemainingForAnOverpaidBooking() {
        Booking b = booking(DepositType.FULL_PAYMENT, "10000", null);
        b.recordPayment(bd("10000"));

        b.reduceTotalPrice(bd("7000"));

        assertThat(b.getRemainingAmount()).isEqualByComparingTo("0");
        assertThat(b.isFullyPaid()).isTrue();
    }

    @Test
    void statusTransitionsAreRecorded() {
        Booking b = booking(DepositType.NO_PAYMENT, "10000", null);

        b.markConfirmed();
        assertThat(b.getStatus()).isEqualTo(BookingStatus.CONFIRMED);

        b.markCompleted();
        assertThat(b.getStatus()).isEqualTo(BookingStatus.COMPLETED);

        Booking other = booking(DepositType.NO_PAYMENT, "10000", null);
        other.markNoShow();
        assertThat(other.getStatus()).isEqualTo(BookingStatus.NO_SHOW);
    }

    @Test
    void markCancelledKeepsTheReason() {
        Booking b = booking(DepositType.NO_PAYMENT, "10000", null);

        b.markCancelled("customer changed plans");

        assertThat(b.getStatus()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(b.getCancellationReason()).isEqualTo("customer changed plans");
    }

    @Test
    void movingToAnotherSlotResetsTheReminder() {
        Booking b = booking(DepositType.NO_PAYMENT, "10000", null);
        b.markReminderSent(NOW);
        UUID newSlot = UUID.randomUUID();

        b.moveToSlot(newSlot);

        assertThat(b.getAvailabilitySlotId()).isEqualTo(newSlot);
        assertThat(b.getReminderSentAt()).isNull();
    }
}
