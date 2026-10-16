package com.zairo.factory.providerinsights;

import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.OverviewResponse;
import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.reviews.ReviewRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
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
    private final AvailabilitySlotRepository slotRepository;
    private final BookingRepository bookingRepository;
    private final ApplicationEventPublisher eventPublisher;

    public WeeklyBusinessReportService(ProviderRepository providerRepository,
            BusinessAnalyticsService analyticsService, ReviewRepository reviewRepository,
            AvailabilitySlotRepository slotRepository, BookingRepository bookingRepository,
            ApplicationEventPublisher eventPublisher) {
        this.providerRepository = providerRepository;
        this.analyticsService = analyticsService;
        this.reviewRepository = reviewRepository;
        this.slotRepository = slotRepository;
        this.bookingRepository = bookingRepository;
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
                    rating.getReviewCount(), topCancelReasons(provider, from, now)));
            published++;
        }
        return published;
    }

    /** The reasons cancelled bookings of the week gave, most frequent first, at most three. */
    private Map<String, Long> topCancelReasons(Provider provider, Instant from, Instant to) {
        List<UUID> slotIds = slotRepository.findByProviderIdAndStartsAtBetween(provider.getId(), from, to).stream()
                .map(AvailabilitySlot::getId).toList();
        if (slotIds.isEmpty()) {
            return Map.of();
        }
        Map<String, Long> counts = bookingRepository.findByAvailabilitySlotIdIn(slotIds).stream()
                .filter(b -> b.getStatus() == BookingStatus.CANCELLED)
                .map(b -> b.getCancellationReason())
                .filter(reason -> reason != null && !reason.isBlank())
                .collect(Collectors.groupingBy(reason -> reason, Collectors.counting()));
        Map<String, Long> top = new LinkedHashMap<>();
        counts.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed().thenComparing(Map.Entry.comparingByKey()))
                .limit(3).forEach(e -> top.put(e.getKey(), e.getValue()));
        return top;
    }
}
