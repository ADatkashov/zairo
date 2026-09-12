package com.zairo.factory.reactivationengine;

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
    private final DecisionEngine decisionEngine;
    private final Clock clock;

    ReactivationDiscoveryService(BookingRepository bookingRepository, ReactivationCampaignRepository campaignRepository,
            ReactivationCampaignService campaignService, ReactivationProperties properties,
            DecisionEngine decisionEngine, Clock clock) {
        this.bookingRepository = bookingRepository;
        this.campaignRepository = campaignRepository;
        this.campaignService = campaignService;
        this.properties = properties;
        this.decisionEngine = decisionEngine;
        this.clock = clock;
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
        Instant flatFloor = now.minus(properties.scanMinimumInactivityDays(), ChronoUnit.DAYS);

        List<LatestCompletedVisitRow> pairs = bookingRepository.findLatestCompletedVisitPerUserAndProvider();
        for (LatestCompletedVisitRow row : pairs) {
            try {
                if (!row.getLastVisitAt().isBefore(flatFloor)) {
                    continue;
                }
                if (campaignRepository.existsByLastVisitBookingId(row.getBookingId())) {
                    continue;
                }
                long inactiveDays = Duration.between(row.getLastVisitAt(), now).toDays();
                Long averageIntervalDays = campaignService.computeAverageIntervalDays(row.getUserId(),
                        row.getProviderId());
                if (!properties.isSignificantlyOverdue(inactiveDays, averageIntervalDays)) {
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
