package com.zairo.factory.customerintelligence;

import java.time.Clock;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * The public seam every other module reads Customer Intelligence through --
 * see this module's own package-info for the three-scope model and the
 * "computed on events, not on read" design.
 *
 * <p>Read methods are a read-through cache: a profile that has already been
 * calculated is returned as-is (cheap, no booking-history re-read); a
 * profile that has never been calculated (a user/business pair with no
 * qualifying event yet -- e.g. historical data predating this module) is
 * calculated once, persisted, and returned, so later reads hit the cache
 * too. This is the one place this module ever calculates on a read path,
 * and only once per (user, scope) until the next real event.
 */
@Service
public class CustomerIntelligenceService {

    private final CustomerProfileRepository profileRepository;
    private final CustomerProviderProfileRepository providerProfileRepository;
    private final CustomerEmployeeProfileRepository employeeProfileRepository;
    private final CustomerProfileCalculator profileCalculator;
    private final CustomerProviderProfileCalculator providerProfileCalculator;
    private final CustomerEmployeeProfileCalculator employeeProfileCalculator;
    private final Clock clock;

    CustomerIntelligenceService(CustomerProfileRepository profileRepository,
            CustomerProviderProfileRepository providerProfileRepository,
            CustomerEmployeeProfileRepository employeeProfileRepository, CustomerProfileCalculator profileCalculator,
            CustomerProviderProfileCalculator providerProfileCalculator,
            CustomerEmployeeProfileCalculator employeeProfileCalculator, Clock clock) {
        this.profileRepository = profileRepository;
        this.providerProfileRepository = providerProfileRepository;
        this.employeeProfileRepository = employeeProfileRepository;
        this.profileCalculator = profileCalculator;
        this.providerProfileCalculator = providerProfileCalculator;
        this.employeeProfileCalculator = employeeProfileCalculator;
        this.clock = clock;
    }

    /**
     * Explicit recalculation -- also what {@link CustomerIntelligenceBookingListener} calls after a relevant booking
     * event, i.e. from an AFTER_COMMIT callback, where joining the (already completed) booking transaction fails with
     * "No active transaction" and, because it throws, cuts off every listener registered after this one (notably the
     * refund request's eager nudge). Hence {@code REQUIRES_NEW}, the same fix notifications uses for the same reason.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public CustomerProfile recalculateProfile(UUID userId) {
        return profileCalculator.recalculate(userId, clock.instant());
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public CustomerProviderProfile recalculateProviderProfile(UUID userId, UUID providerId) {
        return providerProfileCalculator.recalculate(userId, providerId, clock.instant());
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public CustomerEmployeeProfile recalculateEmployeeProfile(UUID userId, UUID providerId, UUID employeeId) {
        return employeeProfileCalculator.recalculate(userId, providerId, employeeId, clock.instant());
    }

    public Optional<CustomerProfile> findProfile(UUID userId) {
        return profileRepository.findByUserId(userId);
    }

    public Optional<CustomerProviderProfile> findProviderProfile(UUID userId, UUID providerId) {
        return providerProfileRepository.findByUserIdAndProviderId(userId, providerId);
    }

    /** Read-through: calculates once if this customer has never been seen before, otherwise returns the cached row. */
    @Transactional
    public CustomerProfile getOrCalculateProfile(UUID userId) {
        return profileRepository.findByUserId(userId).orElseGet(() -> recalculateProfile(userId));
    }

    /** Read-through, scoped to one business -- the business-admin read (see {@code CustomerIntelligenceController}). */
    @Transactional
    public CustomerProviderProfile getOrCalculateProviderProfile(UUID userId, UUID providerId) {
        return providerProfileRepository.findByUserIdAndProviderId(userId, providerId)
                .orElseGet(() -> recalculateProviderProfile(userId, providerId));
    }

    /**
     * Revenue Engine's bulk read -- one query for a whole candidate pool
     * (see {@code smartfill.CandidateFinder}), not one lookup per candidate.
     * Deliberately read-only, no calculate-on-miss here: a candidate with no
     * row yet simply has no signal to offer (equivalent to "no relationship"),
     * which is the correct default for a scoring pass that runs far more
     * often than any one customer's history changes -- calculating on every
     * campaign for every candidate would defeat the point of persisting
     * this in the first place.
     */
    public Map<UUID, CustomerProviderProfile> findProviderProfiles(UUID providerId, Collection<UUID> userIds) {
        if (userIds.isEmpty()) {
            return Map.of();
        }
        return providerProfileRepository.findByProviderIdAndUserIdIn(providerId, userIds).stream()
                .collect(Collectors.toMap(CustomerProviderProfile::getUserId, profile -> profile));
    }
}
