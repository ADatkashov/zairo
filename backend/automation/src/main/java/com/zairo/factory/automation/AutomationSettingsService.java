package com.zairo.factory.automation;

import com.zairo.factory.automation.AutomationDtos.UpdateAutomationSettingsRequest;
import java.time.Clock;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Owner-only CRUD over a business's own {@link AutomationSettings}, plus the
 * read-only helpers {@code smartfill}/{@code rebookengine}/{@code
 * reactivationengine} call to decide whether/how to run for a given
 * provider. Ownership itself is checked by the caller (see {@link
 * AutomationSettingsController}) -- the three engine modules that read
 * settings never need it, since they already resolved the provider from
 * their own trusted domain events, not a caller-supplied id.
 */
@Service
public class AutomationSettingsService {

    private final AutomationSettingsRepository repository;
    private final Clock clock;

    public AutomationSettingsService(AutomationSettingsRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    /** Read-only helper for the engine modules -- empty if the business has never touched its automation settings. */
    public Optional<AutomationSettings> findByProviderId(UUID providerId) {
        return repository.findByProviderId(providerId);
    }

    /**
     * True if {@code now} falls inside this provider's configured
     * allowed-hours window (or if the provider has never configured one at
     * all, which always allows -- see {@link AutomationSettings#isWithinAllowedHours}).
     * The engines call this before actually sending a nudge, never before
     * discovering/creating a campaign -- a candidate found at 2am is still
     * worth creating, just not worth waking someone up for.
     */
    public boolean isWithinAllowedHours(UUID providerId, Instant now) {
        return findByProviderId(providerId).map(s -> s.isWithinAllowedHours(now)).orElse(true);
    }

    /** The settings row, creating an all-enabled/all-default draft on first access -- never null. */
    @Transactional
    public AutomationSettings getOrCreateDraft(UUID providerId) {
        return repository.findByProviderId(providerId)
                .orElseGet(() -> repository.save(new AutomationSettings(UUID.randomUUID(), providerId, clock.instant())));
    }

    @Transactional
    public AutomationSettings updateSettings(UUID providerId, UpdateAutomationSettingsRequest request) {
        validate(request);
        AutomationSettings settings = getOrCreateDraft(providerId);
        settings.applySettings(request.rebookEnabled(), request.reactivationEnabled(), request.smartFillEnabled(),
                request.rebookMinVisitsToEstablishInterval(), request.rebookMinIntervalDays(),
                request.rebookMaxIntervalDays(), request.rebookFollowUpWindowDays(),
                request.reactivationScanMinInactivityDays(), request.reactivationIntervalMultiplier(),
                request.reactivationAbsoluteMaxInactivityDays(), request.reactivationFollowUpWindowDays(),
                request.allowedHoursStart(), request.allowedHoursEnd(), request.timezone(),
                request.cooldownDaysBetweenOffers(), clock.instant());
        return repository.save(settings);
    }

    private void validate(UpdateAutomationSettingsRequest r) {
        if (positiveOrNull(r.rebookMinVisitsToEstablishInterval(), 1)) {
            throw badRequest("rebookMinVisitsToEstablishInterval must be at least 1");
        }
        if (positiveOrNull(r.rebookMinIntervalDays(), 1)) {
            throw badRequest("rebookMinIntervalDays must be at least 1");
        }
        if (positiveOrNull(r.rebookFollowUpWindowDays(), 1)) {
            throw badRequest("rebookFollowUpWindowDays must be at least 1");
        }
        if (r.rebookMinIntervalDays() != null && r.rebookMaxIntervalDays() != null
                && r.rebookMaxIntervalDays() < r.rebookMinIntervalDays()) {
            throw badRequest("rebookMaxIntervalDays must be >= rebookMinIntervalDays");
        }
        if (positiveOrNull(r.reactivationScanMinInactivityDays(), 1)) {
            throw badRequest("reactivationScanMinInactivityDays must be at least 1");
        }
        if (r.reactivationIntervalMultiplier() != null && r.reactivationIntervalMultiplier() <= 0) {
            throw badRequest("reactivationIntervalMultiplier must be positive");
        }
        if (positiveOrNull(r.reactivationAbsoluteMaxInactivityDays(), 1)) {
            throw badRequest("reactivationAbsoluteMaxInactivityDays must be at least 1");
        }
        if (positiveOrNull(r.reactivationFollowUpWindowDays(), 1)) {
            throw badRequest("reactivationFollowUpWindowDays must be at least 1");
        }
        if ((r.allowedHoursStart() == null) != (r.allowedHoursEnd() == null)) {
            throw badRequest("allowedHoursStart and allowedHoursEnd must be set together, or not at all");
        }
        if (outOfRange(r.allowedHoursStart()) || outOfRange(r.allowedHoursEnd())) {
            throw badRequest("allowedHoursStart/allowedHoursEnd must be between 0 and 23");
        }
        if (r.timezone() != null) {
            try {
                ZoneId.of(r.timezone());
            } catch (DateTimeException e) {
                throw badRequest("timezone must be a valid IANA zone id, e.g. \"Asia/Almaty\": " + r.timezone());
            }
        }
        if (r.cooldownDaysBetweenOffers() != null && r.cooldownDaysBetweenOffers() < 0) {
            throw badRequest("cooldownDaysBetweenOffers must not be negative");
        }
    }

    private static boolean positiveOrNull(Integer value, int min) {
        return value != null && value < min;
    }

    private static boolean outOfRange(Integer hour) {
        return hour != null && (hour < 0 || hour > 23);
    }

    private static ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
