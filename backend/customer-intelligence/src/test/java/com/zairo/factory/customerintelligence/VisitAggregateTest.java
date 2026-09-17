package com.zairo.factory.customerintelligence;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Tests the shared calculation core -- see this module's own task brief's data-quality rules. */
class VisitAggregateTest {

    private static final CustomerIntelligenceProperties PROPERTIES = new CustomerIntelligenceProperties(
            new CustomerIntelligenceProperties.Interval(2),
            new CustomerIntelligenceProperties.Retention(1.15, 2.0, 3.0, 60, 120),
            new CustomerIntelligenceProperties.Value(20, new BigDecimal("2000"), 180, 0.30, 0.30, 0.15, 0.15, 0.10));

    private static final UUID PROVIDER_ID = UUID.randomUUID();
    private static final UUID SERVICE_ID = UUID.randomUUID();
    private static final UUID EMPLOYEE_ID = UUID.randomUUID();

    @Test
    void emptyHistoryProducesASafeAllZeroResult() {
        VisitAggregate aggregate = VisitAggregate.compute(List.of(), PROPERTIES, Instant.now());

        assertEquals(0, aggregate.totalBookings());
        assertEquals(0, aggregate.completedBookings());
        assertEquals(0, BigDecimal.ZERO.compareTo(aggregate.totalSpent()));
        assertNull(aggregate.averageBookingValue());
        assertNull(aggregate.averageVisitIntervalDays());
        assertNull(aggregate.attendanceRate());
        assertEquals(0.0, aggregate.cancellationRate());
        assertEquals(RetentionStatus.NEW, aggregate.retentionStatus());
        assertTrue(aggregate.preferredBookingDays().isEmpty());
        assertEquals(PreferredTimeRange.UNKNOWN, aggregate.preferredBookingTimeRange());
    }

    @Test
    void onlyCompletedBookingsCountTowardsSpendAndVisitCount() {
        Instant now = Instant.now();
        List<VisitRecord> visits = List.of(
                visit(BookingStatus.COMPLETED, now.minus(10, ChronoUnit.DAYS), "50.00"),
                visit(BookingStatus.CANCELLED, now.minus(5, ChronoUnit.DAYS), "999.00"),
                visit(BookingStatus.NO_SHOW, now.minus(3, ChronoUnit.DAYS), "999.00"));

        VisitAggregate aggregate = VisitAggregate.compute(visits, PROPERTIES, now);

        assertEquals(3, aggregate.totalBookings());
        assertEquals(1, aggregate.completedBookings());
        assertEquals(1, aggregate.cancelledBookings());
        assertEquals(1, aggregate.noShows());
        assertEquals(0, new BigDecimal("50.00").compareTo(aggregate.totalSpent()));
        assertEquals(0, new BigDecimal("50.00").compareTo(aggregate.averageBookingValue()));
    }

    @Test
    void attendanceRateIsCompletedOverCompletedPlusNoShow() {
        Instant now = Instant.now();
        List<VisitRecord> visits = List.of(
                visit(BookingStatus.COMPLETED, now.minus(30, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.COMPLETED, now.minus(20, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.COMPLETED, now.minus(10, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.NO_SHOW, now.minus(5, ChronoUnit.DAYS), "10.00"));

        VisitAggregate aggregate = VisitAggregate.compute(visits, PROPERTIES, now);

        assertEquals(0.75, aggregate.attendanceRate());
    }

    @Test
    void cancellationRateIsCancelledOverAllBookings() {
        Instant now = Instant.now();
        List<VisitRecord> visits = List.of(
                visit(BookingStatus.COMPLETED, now.minus(30, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.CANCELLED, now.minus(20, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.CANCELLED, now.minus(10, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.CANCELLED, now.minus(5, ChronoUnit.DAYS), "10.00"));

        VisitAggregate aggregate = VisitAggregate.compute(visits, PROPERTIES, now);

        assertEquals(0.75, aggregate.cancellationRate());
    }

    @Test
    void averageVisitIntervalIsTheMeanGapBetweenCompletedVisits() {
        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        List<VisitRecord> visits = List.of(
                visit(BookingStatus.COMPLETED, today.minus(60, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.COMPLETED, today.minus(30, ChronoUnit.DAYS), "10.00"),
                visit(BookingStatus.COMPLETED, today, "10.00"));

        VisitAggregate aggregate = VisitAggregate.compute(visits, PROPERTIES, today.plus(1, ChronoUnit.HOURS));

        assertEquals(30, aggregate.averageVisitIntervalDays());
        assertEquals(today.plus(30, ChronoUnit.DAYS), aggregate.nextExpectedVisitAt());
    }

    @Test
    void aSingleCompletedVisitEstablishesNoInterval() {
        Instant now = Instant.now();
        List<VisitRecord> visits = List.of(visit(BookingStatus.COMPLETED, now.minus(5, ChronoUnit.DAYS), "10.00"));

        VisitAggregate aggregate = VisitAggregate.compute(visits, PROPERTIES, now);

        assertNull(aggregate.averageVisitIntervalDays());
        assertNull(aggregate.nextExpectedVisitAt());
    }

    @Test
    void aFutureDatedCompletedSlotIsNeverTreatedAsAPastVisit() {
        Instant now = Instant.now();
        List<VisitRecord> visits = List.of(visit(BookingStatus.COMPLETED, now.plus(5, ChronoUnit.DAYS), "10.00"));

        VisitAggregate aggregate = VisitAggregate.compute(visits, PROPERTIES, now);

        assertEquals(0, aggregate.completedBookings());
        assertNull(aggregate.lastCompletedBookingAt());
    }

    @Test
    void duplicateRecalculationFromTheSameHistoryIsIdempotent() {
        Instant now = Instant.now();
        List<VisitRecord> visits = List.of(
                visit(BookingStatus.COMPLETED, now.minus(40, ChronoUnit.DAYS), "25.00"),
                visit(BookingStatus.COMPLETED, now.minus(10, ChronoUnit.DAYS), "25.00"));

        VisitAggregate first = VisitAggregate.compute(visits, PROPERTIES, now);
        VisitAggregate second = VisitAggregate.compute(visits, PROPERTIES, now);

        assertEquals(first, second);
    }

    private static VisitRecord visit(BookingStatus status, Instant startsAt, String price) {
        return new VisitRecord(UUID.randomUUID(), PROVIDER_ID, SERVICE_ID, EMPLOYEE_ID, status, startsAt,
                startsAt.minus(1, ChronoUnit.HOURS), new BigDecimal(price), "USD");
    }
}
