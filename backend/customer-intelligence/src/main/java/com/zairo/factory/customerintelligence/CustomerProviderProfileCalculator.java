package com.zairo.factory.customerintelligence;

import com.zairo.factory.booking.BookingStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.function.Consumer;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;

/**
 * Computes and persists {@link CustomerProviderProfile} -- one customer's
 * relationship with one specific business. Always a full recomputation from
 * {@link BookingHistoryReader#forUserAndProvider}, same idempotency
 * reasoning as {@link CustomerProfileCalculator}.
 */
@Component
class CustomerProviderProfileCalculator {

    private final BookingHistoryReader historyReader;
    private final CustomerProviderProfileRepository repository;
    private final CustomerIntelligenceProperties properties;
    private final CustomerValueCalculator valueCalculator;

    CustomerProviderProfileCalculator(BookingHistoryReader historyReader, CustomerProviderProfileRepository repository,
            CustomerIntelligenceProperties properties, CustomerValueCalculator valueCalculator) {
        this.historyReader = historyReader;
        this.repository = repository;
        this.properties = properties;
        this.valueCalculator = valueCalculator;
    }

    CustomerProviderProfile recalculate(UUID userId, UUID providerId, Instant now) {
        List<VisitRecord> visits = historyReader.forUserAndProvider(userId, providerId);
        VisitAggregate aggregate = VisitAggregate.compute(visits, properties, now);

        List<VisitRecord> completed = visits.stream()
                .filter(v -> v.status() == BookingStatus.COMPLETED && !v.startsAt().isAfter(now)).toList();

        UUID favouriteEmployeeId = MostFrequent.of(completed, VisitRecord::employeeId).orElse(null);
        UUID favouriteServiceId = MostFrequent.of(completed, VisitRecord::serviceId).orElse(null);

        BigDecimal relationshipScore = valueCalculator.score(new CustomerValueCalculator.Inputs(
                aggregate.completedBookings(), aggregate.totalSpent(), aggregate.attendanceRate(),
                aggregate.lastCompletedBookingAt(), aggregate.completedBookings() >= 2, now));

        return upsert(userId, providerId, profile -> profile.apply(aggregate, favouriteEmployeeId, favouriteServiceId,
                relationshipScore, now));
    }

    /** Same find-or-create-with-retry reasoning as {@code CustomerProfileCalculator#upsert}, keyed on (userId, providerId) instead. */
    private CustomerProviderProfile upsert(UUID userId, UUID providerId, Consumer<CustomerProviderProfile> mutate) {
        CustomerProviderProfile profile = repository.findByUserIdAndProviderId(userId, providerId).orElse(null);
        if (profile == null) {
            profile = new CustomerProviderProfile(UUID.randomUUID(), userId, providerId);
            mutate.accept(profile);
            try {
                return repository.saveAndFlush(profile);
            } catch (DataIntegrityViolationException e) {
                profile = repository.findByUserIdAndProviderId(userId, providerId).orElseThrow(() -> e);
            }
        }
        mutate.accept(profile);
        return repository.save(profile);
    }
}
