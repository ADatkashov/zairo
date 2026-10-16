package com.zairo.factory.providerinsights;

import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.OverviewResponse;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.reviews.ReviewRepository;
import java.time.Duration;
import java.time.Instant;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;

/**
 * "Your week in numbers" — for every business that had at least one booking in the past seven days, publishes a
 * {@link WeeklyBusinessReportEvent} built from the same overview the owner sees in the app. A quiet business gets no
 * email: an empty report is noise. Runs once a week (see {@link WeeklyBusinessReportJob}); the figures are computed on
 * demand, no table of its own.
 */
@Service
public class WeeklyBusinessReportService {

    static final Duration PERIOD = Duration.ofDays(7);

    private final ProviderRepository providerRepository;
    private final BusinessAnalyticsService analyticsService;
    private final ReviewRepository reviewRepository;
    private final ApplicationEventPublisher eventPublisher;

    public WeeklyBusinessReportService(ProviderRepository providerRepository,
            BusinessAnalyticsService analyticsService, ReviewRepository reviewRepository,
            ApplicationEventPublisher eventPublisher) {
        this.providerRepository = providerRepository;
        this.analyticsService = analyticsService;
        this.reviewRepository = reviewRepository;
        this.eventPublisher = eventPublisher;
    }

    /** Publishes one report per business with bookings in the seven days before [now]; returns how many. */
    public int publishReports(Instant now) {
        Instant from = now.minus(PERIOD);
        int published = 0;
        for (Provider provider : providerRepository.findAll()) {
            OverviewResponse overview = analyticsService.overview(provider.getId(), from, now);
            if (overview.totalBookings() == 0) {
                continue;
            }
            OverviewResponse before = analyticsService.overview(provider.getId(), from.minus(PERIOD), from);
            var rating = reviewRepository.ratingInPeriod(provider.getId(), from, now);
            eventPublisher.publishEvent(new WeeklyBusinessReportEvent(provider.getId(), provider.getName(), from, now,
                    overview.totalBookings(), overview.completedBookings(), overview.cancelledBookings(),
                    overview.noShowBookings(), overview.totalRevenue(), overview.currency(),
                    before.totalBookings(), before.totalRevenue(), rating.getAverageRating(),
                    rating.getReviewCount()));
            published++;
        }
        return published;
    }
}
