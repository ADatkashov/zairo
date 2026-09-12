package com.zairo.factory.customerintelligence;

import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;

/**
 * Computes and persists {@link CustomerProfile} -- one customer's behaviour
 * across every business on the platform. Always a full recomputation from
 * {@link BookingHistoryReader#forUser}, never an incremental update (see
 * {@link VisitAggregate}'s own doc comment on why that matters for
 * idempotency).
 */
@Component
class CustomerProfileCalculator {

    private final BookingHistoryReader historyReader;
    private final CustomerProfileRepository repository;
    private final CustomerIntelligenceProperties properties;
    private final CustomerValueCalculator valueCalculator;

    CustomerProfileCalculator(BookingHistoryReader historyReader, CustomerProfileRepository repository,
            CustomerIntelligenceProperties properties, CustomerValueCalculator valueCalculator) {
        this.historyReader = historyReader;
        this.repository = repository;
        this.properties = properties;
        this.valueCalculator = valueCalculator;
    }

    CustomerProfile recalculate(UUID userId, Instant now) {
        List<VisitRecord> visits = historyReader.forUser(userId);
        VisitAggregate aggregate = VisitAggregate.compute(visits, properties, now);

        List<VisitRecord> completed = visits.stream()
                .filter(v -> v.status() == BookingStatus.COMPLETED && !v.startsAt().isAfter(now)).toList();

        double repeatBookingRate = repeatBookingRate(completed);
        UUID favouriteProviderId = MostFrequent.of(completed, VisitRecord::providerId).orElse(null);
        UUID favouriteServiceId = MostFrequent.of(completed, VisitRecord::serviceId).orElse(null);

        BigDecimal valueScore = valueCalculator.score(new CustomerValueCalculator.Inputs(aggregate.completedBookings(),
                aggregate.totalSpent(), aggregate.attendanceRate(), aggregate.lastCompletedBookingAt(),
                repeatBookingRate > 0, now));

        return upsert(userId, profile -> profile.apply(aggregate, repeatBookingRate, favouriteProviderId,
                favouriteServiceId, valueScore, now));
    }

    /** Fraction of distinct businesses this customer has completed more than one booking with -- "do they come back." */
    private static double repeatBookingRate(List<VisitRecord> completed) {
        Map<UUID, Long> byProvider = completed.stream()
                .collect(Collectors.groupingBy(VisitRecord::providerId, Collectors.counting()));
        if (byProvider.isEmpty()) {
            return 0.0;
        }
        long repeatProviders = byProvider.values().stream().filter(count -> count >= 2).count();
        return repeatProviders / (double) byProvider.size();
    }

    /**
     * Find-or-create with a retry on the unique {@code user_id} constraint --
     * two concurrent recalculations for a brand-new customer's first two
     * bookings (e.g. a duplicated event delivery racing a real second event)
     * can both miss the row on {@link CustomerProfileRepository#findByUserId}
     * before either commits; the loser's insert fails the unique index
     * instead of creating a duplicate row, and retries against the winner's
     * row instead. {@code saveAndFlush} (not plain {@code save}) so the
     * insert's own constraint violation surfaces here, inside the
     * try/catch, rather than later at transaction commit.
     */
    private CustomerProfile upsert(UUID userId, java.util.function.Consumer<CustomerProfile> mutate) {
        CustomerProfile profile = repository.findByUserId(userId).orElse(null);
        if (profile == null) {
            profile = new CustomerProfile(UUID.randomUUID(), userId);
            mutate.accept(profile);
            try {
                return repository.saveAndFlush(profile);
            } catch (DataIntegrityViolationException e) {
                profile = repository.findByUserId(userId)
                        .orElseThrow(() -> e);
            }
        }
        mutate.accept(profile);
        return repository.save(profile);
    }
}
