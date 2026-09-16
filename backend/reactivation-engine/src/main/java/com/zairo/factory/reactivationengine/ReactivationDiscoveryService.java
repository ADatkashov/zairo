package com.zairo.factory.reactivationengine;

import com.zairo.factory.automation.AutomationSettings;
import com.zairo.factory.automation.AutomationSettingsService;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingRepository.LatestCompletedVisitRow;
import com.zairo.factory.revenueengine.DecisionContext;
import com.zairo.factory.revenueengine.DecisionEngine;
import com.zairo.factory.revenueengine.DecisionTrigger;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * {@link ReactivationCandidateDiscoveryJob}'s one call -- the whole trigger
 * for {@code revenueengine.DecisionTrigger#CUSTOMER_INACTIVE} (see that
 * constant's own doc comment for why this is a scan rather than a
 * listener). Kept as its own class, separate from {@link
 * ReactivationCampaignService}, specifically to avoid a circular bean
 * dependency: this class depends on {@link DecisionEngine}, and {@link
 * DecisionEngine} depends (transitively, via the {@code RevenueStrategy}
 * list it collects) on {@link ReactivationCampaignService} -- if this scan
 * lived on that service instead, Spring couldn't construct either bean.
 */
@Service
public class ReactivationDiscoveryService {

    private static final Logger log = LoggerFactory.getLogger(ReactivationDiscoveryService.class);

    private final BookingRepository bookingRepository;
    private final ReactivationCampaignRepository campaignRepository;
    private final ReactivationCampaignService campaignService;
    private final ReactivationProperties properties;
    private final AutomationSettingsService automationSettingsService;
    private final DecisionEngine decisionEngine;
    private final Clock clock;

    ReactivationDiscoveryService(BookingRepository bookingRepository, ReactivationCampaignRepository campaignRepository,
            ReactivationCampaignService campaignService, ReactivationProperties properties,
            AutomationSettingsService automationSettingsService, DecisionEngine decisionEngine, Clock clock) {
        this.bookingRepository = bookingRepository;
        this.campaignRepository = campaignRepository;
        this.campaignService = campaignService;
        this.properties = properties;
        this.automationSettingsService = automationSettingsService;
        this.decisionEngine = decisionEngine;
        this.clock = clock;
    }

    /** Merges this provider's overrides onto {@link ReactivationProperties}' global defaults, same split as {@code rebookengine.RebookCampaignService}'s own resolver. */
    private record EffectiveConfig(int scanMinimumInactivityDays, double intervalMultiplier,
            int absoluteMaxInactivityDays) {

        boolean isSignificantlyOverdue(long inactiveDays, Long averageIntervalDays) {
            if (inactiveDays >= absoluteMaxInactivityDays) {
                return true;
            }
            return averageIntervalDays != null && inactiveDays >= averageIntervalDays * intervalMultiplier;
        }
    }

    private EffectiveConfig resolveEffectiveConfig(AutomationSettings settings) {
        if (settings == null) {
            return new EffectiveConfig(properties.scanMinimumInactivityDays(), properties.intervalMultiplier(),
                    properties.absoluteMaxInactivityDays());
        }
        return new EffectiveConfig(
                orDefault(settings.getReactivationScanMinInactivityDays(), properties.scanMinimumInactivityDays()),
                settings.getReactivationIntervalMultiplier() != null ? settings.getReactivationIntervalMultiplier()
                        : properties.intervalMultiplier(),
                orDefault(settings.getReactivationAbsoluteMaxInactivityDays(), properties.absoluteMaxInactivityDays()));
    }

    private static int orDefault(Integer override, int fallback) {
        return override != null ? override : fallback;
    }

    /**
     * For every customer+provider pair the platform has ever seen, asks the
     * Decision Engine to weigh in the moment that pair looks significantly
     * overdue -- see {@link ReactivationProperties#isSignificantlyOverdue}.
     * Same "one call per candidate inside the sweep, catch and log rather
     * than let one failure kill the whole pass" shape as {@code
     * smartfill.SmartFillCampaignJob}/{@code rebookengine.RebookCampaignJob}.
     */
    public void scanForInactiveCustomers() {
        Instant now = clock.instant();

        List<LatestCompletedVisitRow> pairs = bookingRepository.findLatestCompletedVisitPerUserAndProvider();
        for (LatestCompletedVisitRow row : pairs) {
            try {
                AutomationSettings settings = automationSettingsService.findByProviderId(row.getProviderId())
                        .orElse(null);
                EffectiveConfig config = resolveEffectiveConfig(settings);

                Instant flatFloor = now.minus(config.scanMinimumInactivityDays(), ChronoUnit.DAYS);
                if (!row.getLastVisitAt().isBefore(flatFloor)) {
                    continue;
                }
                if (campaignRepository.existsByLastVisitBookingId(row.getBookingId())) {
                    continue;
                }
                // Outside this provider's allowed-hours window: leave the
                // candidate undiscovered for now (no campaign created yet,
                // so the unique-index guard above hasn't fired) -- tomorrow's
                // sweep picks it back up. Coarser than Rebook's own hourly
                // deferred-send job since this sweep itself only runs daily
                // (ADR-0005); tightening that would mean giving Reactivation
                // Rebook's two-step CREATED-then-sent lifecycle, which is a
                // bigger change than this pass makes.
                if (!automationSettingsService.isWithinAllowedHours(row.getProviderId(), now)) {
                    continue;
                }
                Integer cooldownDays = settings == null ? null : settings.getCooldownDaysBetweenOffers();
                if (cooldownDays != null && campaignRepository.existsByUserIdAndProviderIdAndCreatedAtGreaterThan(
                        row.getUserId(), row.getProviderId(), now.minus(cooldownDays, ChronoUnit.DAYS))) {
                    continue;
                }
                long inactiveDays = Duration.between(row.getLastVisitAt(), now).toDays();
                Long averageIntervalDays = campaignService.computeAverageIntervalDays(row.getUserId(),
                        row.getProviderId());
                if (!config.isSignificantlyOverdue(inactiveDays, averageIntervalDays)) {
                    continue;
                }
                decisionEngine.decideAndExecute(new DecisionContext(DecisionTrigger.CUSTOMER_INACTIVE,
                        row.getProviderId(), row.getBookingId(), now));
            } catch (RuntimeException e) {
                log.error("Failed to evaluate inactivity candidate (user {}, provider {}): {}", row.getUserId(),
                        row.getProviderId(), e.getMessage(), e);
            }
        }
    }
}
