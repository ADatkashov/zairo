package com.zairo.factory.customerintelligence;

import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * The calculation core shared by {@link CustomerProfileCalculator} and
 * {@link CustomerProviderProfileCalculator} -- everything that can be
 * derived from one flat list of {@link VisitRecord}s, regardless of whether
 * that list is "this customer, everywhere" or "this customer, at this one
 * business". {@link CustomerEmployeeProfileCalculator} needs a smaller
 * subset of this and computes it directly rather than forcing every field
 * here (see that class's own doc comment).
 *
 * <h2>Data quality rules (see this module's own task brief)</h2>
 * Only {@code COMPLETED} bookings count as real visits and real spend --
 * {@code CANCELLED} never contributes to spend/interval/preferences, and
 * {@code NO_SHOW} never counts as an attended visit even though the
 * customer was charged. Everything here is deterministic and computed
 * fresh from the full visit list every time (never incremented), so a
 * duplicated event or an out-of-order recalculation always lands on the
 * same answer -- see {@link CustomerIntelligenceBookingListener}.
 */
record VisitAggregate(
        int totalBookings,
        int completedBookings,
        int cancelledBookings,
        int noShows,
        BigDecimal totalSpent,
        String currency,
        BigDecimal averageBookingValue,
        Instant firstBookingAt,
        Instant lastBookingAt,
        Instant lastCompletedBookingAt,
        Integer averageVisitIntervalDays,
        List<DayOfWeek> preferredBookingDays,
        PreferredTimeRange preferredBookingTimeRange,
        Double attendanceRate,
        double cancellationRate,
        Instant nextExpectedVisitAt,
        RetentionStatus retentionStatus) {

    private static final int MAX_PREFERRED_DAYS = 2;

    static VisitAggregate compute(List<VisitRecord> visits, CustomerIntelligenceProperties properties, Instant now) {
        List<VisitRecord> completed = visits.stream().filter(v -> v.status() == BookingStatus.COMPLETED
                // A "completed" slot that somehow starts in the future is not a real historical visit --
                // guards against bad/backfilled data rather than trusting status alone (see task brief:
                // "do not use future bookings as historical visits").
                && !v.startsAt().isAfter(now)).toList();
        List<VisitRecord> cancelled = visits.stream().filter(v -> v.status() == BookingStatus.CANCELLED).toList();
        List<VisitRecord> noShow = visits.stream().filter(v -> v.status() == BookingStatus.NO_SHOW).toList();

        BigDecimal totalSpent = completed.stream().map(VisitRecord::totalPrice).reduce(BigDecimal.ZERO,
                BigDecimal::add);
        String currency = completed.stream().map(VisitRecord::currency).filter(Objects::nonNull).findFirst()
                .orElse(null);
        BigDecimal averageBookingValue = completed.isEmpty() ? null
                : totalSpent.divide(BigDecimal.valueOf(completed.size()), 2, RoundingMode.HALF_UP);

        Instant firstBookingAt = visits.stream().map(VisitRecord::createdAt).min(Comparator.naturalOrder())
                .orElse(null);
        Instant lastBookingAt = visits.stream().map(VisitRecord::createdAt).max(Comparator.naturalOrder())
                .orElse(null);

        List<Instant> completedVisitTimes = completed.stream().map(VisitRecord::startsAt).sorted().toList();
        Instant lastCompletedBookingAt = completedVisitTimes.isEmpty() ? null
                : completedVisitTimes.get(completedVisitTimes.size() - 1);

        Integer averageVisitIntervalDays = averageIntervalDays(completedVisitTimes,
                properties.interval().minCompletedVisitsForInterval());

        List<DayOfWeek> preferredDays = topDays(completedVisitTimes);
        PreferredTimeRange preferredTimeRange = topTimeRange(completedVisitTimes);

        Double attendanceRate = (completed.size() + noShow.size()) == 0 ? null
                : completed.size() / (double) (completed.size() + noShow.size());
        double cancellationRate = visits.isEmpty() ? 0.0 : cancelled.size() / (double) visits.size();

        Instant nextExpectedVisitAt = (lastCompletedBookingAt != null && averageVisitIntervalDays != null)
                ? lastCompletedBookingAt.plus(averageVisitIntervalDays, ChronoUnit.DAYS)
                : null;

        RetentionStatus retentionStatus = RetentionCalculator.classify(lastCompletedBookingAt,
                averageVisitIntervalDays, now, properties.retention());

        return new VisitAggregate(visits.size(), completed.size(), cancelled.size(), noShow.size(), totalSpent,
                currency, averageBookingValue, firstBookingAt, lastBookingAt, lastCompletedBookingAt,
                averageVisitIntervalDays, preferredDays, preferredTimeRange, attendanceRate, cancellationRate,
                nextExpectedVisitAt, retentionStatus);
    }

    private static Integer averageIntervalDays(List<Instant> sortedCompletedVisitTimes, int minVisitsForInterval) {
        if (sortedCompletedVisitTimes.size() < minVisitsForInterval || sortedCompletedVisitTimes.size() < 2) {
            return null;
        }
        long totalDays = 0;
        for (int i = 1; i < sortedCompletedVisitTimes.size(); i++) {
            totalDays += Duration.between(sortedCompletedVisitTimes.get(i - 1), sortedCompletedVisitTimes.get(i))
                    .toDays();
        }
        int gaps = sortedCompletedVisitTimes.size() - 1;
        // At least 1 day -- two visits on the same calendar day would otherwise average to zero,
        // which both divides by zero downstream (next-expected-visit math) and isn't a real cadence.
        return (int) Math.max(1, Math.round(totalDays / (double) gaps));
    }

    private static List<DayOfWeek> topDays(List<Instant> completedVisitTimes) {
        if (completedVisitTimes.isEmpty()) {
            return List.of();
        }
        Map<DayOfWeek, Long> counts = completedVisitTimes.stream()
                .collect(Collectors.groupingBy(t -> t.atZone(ZoneOffset.UTC).getDayOfWeek(), Collectors.counting()));
        return counts.entrySet().stream()
                .sorted(Map.Entry.<DayOfWeek, Long>comparingByValue().reversed()
                        .thenComparing(entry -> entry.getKey().getValue()))
                .limit(MAX_PREFERRED_DAYS)
                .map(Map.Entry::getKey)
                .toList();
    }

    private static PreferredTimeRange topTimeRange(List<Instant> completedVisitTimes) {
        if (completedVisitTimes.isEmpty()) {
            return PreferredTimeRange.UNKNOWN;
        }
        Map<PreferredTimeRange, Long> counts = completedVisitTimes.stream()
                .collect(Collectors.groupingBy(t -> PreferredTimeRange.fromHourOfDayUtc(t.atZone(ZoneOffset.UTC).getHour()),
                        Collectors.counting()));
        return counts.entrySet().stream().max(Map.Entry.comparingByValue()).map(Map.Entry::getKey)
                .orElse(PreferredTimeRange.UNKNOWN);
    }
}
