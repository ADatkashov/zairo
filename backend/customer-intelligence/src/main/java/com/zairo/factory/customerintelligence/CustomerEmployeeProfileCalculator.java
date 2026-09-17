package com.zairo.factory.customerintelligence;

import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Consumer;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;

/**
 * Computes and persists {@link CustomerEmployeeProfile} -- one customer's
 * relationship with one specific employee/master. Lighter than {@link
 * VisitAggregate} (see this module's own package-info): no cancellation/
 * no-show/preferred-day tracking at this granularity, since Smart Fill's
 * own {@code PREVIOUSLY_BOOKED_SAME_EMPLOYEE} use case only ever needs "has
 * this pair worked together, how much, how recently, on what."
 */
@Component
class CustomerEmployeeProfileCalculator {

    private final BookingHistoryReader historyReader;
    private final CustomerEmployeeProfileRepository repository;
    private final CustomerIntelligenceProperties properties;
    private final CustomerValueCalculator valueCalculator;

    CustomerEmployeeProfileCalculator(BookingHistoryReader historyReader, CustomerEmployeeProfileRepository repository,
            CustomerIntelligenceProperties properties, CustomerValueCalculator valueCalculator) {
        this.historyReader = historyReader;
        this.repository = repository;
        this.properties = properties;
        this.valueCalculator = valueCalculator;
    }

    CustomerEmployeeProfile recalculate(UUID userId, UUID providerId, UUID employeeId, Instant now) {
        List<VisitRecord> completed = historyReader.forUserAndProvider(userId, providerId).stream()
                .filter(v -> v.status() == BookingStatus.COMPLETED && !v.startsAt().isAfter(now)
                        && employeeId.equals(v.employeeId()))
                .toList();

        int completedBookings = completed.size();
        BigDecimal totalSpent = completed.stream().map(VisitRecord::totalPrice).reduce(BigDecimal.ZERO,
                BigDecimal::add);
        String currency = completed.stream().map(VisitRecord::currency).filter(Objects::nonNull).findFirst()
                .orElse(null);
        Instant lastVisitAt = completed.stream().map(VisitRecord::startsAt).max(Comparator.naturalOrder())
                .orElse(null);
        List<Instant> visitTimes = completed.stream().map(VisitRecord::startsAt).sorted().toList();
        Integer averageVisitIntervalDays = averageIntervalDays(visitTimes,
                properties.interval().minCompletedVisitsForInterval());
        UUID favouriteServiceId = MostFrequent.of(completed, VisitRecord::serviceId).orElse(null);

        Double attendanceRate = null; // Not tracked at this granularity -- see this class's own doc comment.
        BigDecimal relationshipScore = valueCalculator.score(new CustomerValueCalculator.Inputs(completedBookings,
                totalSpent, attendanceRate, lastVisitAt, completedBookings >= 2, now));

        return upsert(userId, providerId, employeeId, profile -> profile.apply(completedBookings, totalSpent,
                currency, lastVisitAt, averageVisitIntervalDays, favouriteServiceId, relationshipScore, now));
    }

    private static Integer averageIntervalDays(List<Instant> sortedVisitTimes, int minVisitsForInterval) {
        if (sortedVisitTimes.size() < minVisitsForInterval || sortedVisitTimes.size() < 2) {
            return null;
        }
        long totalDays = 0;
        for (int i = 1; i < sortedVisitTimes.size(); i++) {
            totalDays += java.time.Duration.between(sortedVisitTimes.get(i - 1), sortedVisitTimes.get(i)).toDays();
        }
        return (int) Math.max(1, Math.round(totalDays / (double) (sortedVisitTimes.size() - 1)));
    }

    /** Same find-or-create-with-retry reasoning as {@code CustomerProfileCalculator#upsert}, keyed on (userId, providerId, employeeId). */
    private CustomerEmployeeProfile upsert(UUID userId, UUID providerId, UUID employeeId,
            Consumer<CustomerEmployeeProfile> mutate) {
        CustomerEmployeeProfile profile = repository.findByUserIdAndProviderIdAndEmployeeId(userId, providerId,
                employeeId).orElse(null);
        if (profile == null) {
            profile = new CustomerEmployeeProfile(UUID.randomUUID(), userId, providerId, employeeId);
            mutate.accept(profile);
            try {
                return repository.saveAndFlush(profile);
            } catch (DataIntegrityViolationException e) {
                profile = repository.findByUserIdAndProviderIdAndEmployeeId(userId, providerId, employeeId)
                        .orElseThrow(() -> e);
            }
        }
        mutate.accept(profile);
        return repository.save(profile);
    }
}
