package com.zairo.factory.smartfill;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.favorites.Favorite;
import com.zairo.factory.favorites.FavoriteRepository;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Builds the candidate pool for one campaign: every user with a real
 * relationship to this provider (previously booked it, or favorited it --
 * see this class's own note on why "follows this specific employee" isn't a
 * separate signal today), scored and filtered down to who's actually
 * eligible right now. Fetches in a fixed, small number of bulk queries
 * regardless of pool size (one per data source, joined/grouped in memory)
 * rather than one query per candidate -- same "computed fresh, no N+1"
 * discipline as {@code providerinsights.ProviderInsightsService}.
 *
 * <p>ZAIRO has no "follows this specific employee/master" feature today
 * (only {@code favorites.Favorite}, which is provider/business-level) --
 * {@link ScoringFactor#PREVIOUSLY_BOOKED_SAME_EMPLOYEE} stands in for that
 * tier-1 signal using real booking history instead. The day a per-employee
 * follow feature exists, wiring its data in here is additive: a new
 * {@link CandidateSignals} field, a new {@link ScoringFactor}, no change to
 * this class's overall shape.
 */
@Service
class CandidateFinder {

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final FavoriteRepository favoriteRepository;
    private final ProviderRepository providerRepository;
    private final CandidateScorer candidateScorer;
    private final NotificationPolicy notificationPolicy;
    private final SmartFillProperties properties;

    CandidateFinder(BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            FavoriteRepository favoriteRepository, ProviderRepository providerRepository,
            CandidateScorer candidateScorer, NotificationPolicy notificationPolicy, SmartFillProperties properties) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.favoriteRepository = favoriteRepository;
        this.providerRepository = providerRepository;
        this.candidateScorer = candidateScorer;
        this.notificationPolicy = notificationPolicy;
        this.properties = properties;
    }

    /**
     * @param excludedUserId the customer whose cancellation freed this slot -- never a candidate for their own campaign.
     * @return every eligible candidate, highest score first, capped at {@code smartfill.staging.max-candidates-per-campaign}.
     */
    List<ScoredCandidate> findCandidates(SmartFillCampaign campaign, UUID excludedUserId, Instant now) {
        UUID providerId = campaign.getProviderId();

        List<Booking> providerBookings = bookingRepository.findByProviderId(providerId);
        Map<UUID, List<Booking>> providerBookingsByUser = providerBookings.stream()
                .collect(Collectors.groupingBy(Booking::getUserId));

        List<Favorite> favorites = favoriteRepository.findByProviderId(providerId);
        Set<UUID> followerIds = favorites.stream().map(Favorite::getUserId).collect(Collectors.toSet());

        Set<UUID> candidateIds = new HashSet<>(providerBookingsByUser.keySet());
        candidateIds.addAll(followerIds);
        candidateIds.remove(excludedUserId);
        if (candidateIds.isEmpty()) {
            return List.of();
        }

        Map<UUID, AvailabilitySlot> providerSlotsById = availabilitySlotRepository
                .findAllById(providerBookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList())
                .stream().collect(Collectors.toMap(AvailabilitySlot::getId, s -> s));

        List<Booking> candidateBookingsEverywhere = bookingRepository.findByUserIdIn(new ArrayList<>(candidateIds));
        Map<UUID, AvailabilitySlot> allSlotsById = availabilitySlotRepository
                .findAllById(candidateBookingsEverywhere.stream().map(Booking::getAvailabilitySlotId).distinct().toList())
                .stream().collect(Collectors.toMap(AvailabilitySlot::getId, s -> s));
        Map<UUID, List<Booking>> everywhereByUser = candidateBookingsEverywhere.stream()
                .collect(Collectors.groupingBy(Booking::getUserId));

        UUID businessTypeId = providerRepository.findById(providerId).map(Provider::getBusinessTypeId).orElse(null);
        Set<UUID> categoryProviderIds = businessTypeId == null ? Set.of()
                : providerRepository.findByBusinessTypeIdAndStatus(businessTypeId, ProviderStatus.ACTIVE).stream()
                        .map(Provider::getId).collect(Collectors.toSet());

        SmartFillProperties.Scoring scoring = properties.scoring();
        Instant recentVisitCutoff = now.minus(scoring.recentVisitWindowDays(), ChronoUnit.DAYS);
        Instant recentEngagementCutoff = now.minus(scoring.recentEngagementWindowDays(), ChronoUnit.DAYS);
        int slotMinuteOfDay = minuteOfDayUtc(campaign.getSlotStartsAt());

        List<ScoredCandidate> scored = new ArrayList<>();
        for (UUID candidateId : candidateIds) {
            List<Booking> atProvider = providerBookingsByUser.getOrDefault(candidateId, List.of());
            List<Booking> everywhere = everywhereByUser.getOrDefault(candidateId, List.of());

            boolean hasConflict = everywhere.stream()
                    .filter(b -> b.getStatus() == BookingStatus.CONFIRMED || b.getStatus() == BookingStatus.PENDING_PAYMENT)
                    .map(b -> allSlotsById.get(b.getAvailabilitySlotId()))
                    .filter(Objects::nonNull)
                    .anyMatch(s -> s.getStartsAt().isBefore(campaign.getSlotEndsAt())
                            && s.getEndsAt().isAfter(campaign.getSlotStartsAt()));
            if (hasConflict || !notificationPolicy.mayOffer(candidateId, providerId, now)) {
                continue;
            }

            boolean followsProvider = followerIds.contains(candidateId);
            boolean previousProviderBooking = !atProvider.isEmpty();
            boolean previouslyBookedSameService = atProvider.stream()
                    .anyMatch(b -> b.getServiceId().equals(campaign.getServiceId()));
            boolean previouslyBookedSameEmployee = campaign.getEmployeeId() != null && atProvider.stream()
                    .map(b -> providerSlotsById.get(b.getAvailabilitySlotId()))
                    .filter(Objects::nonNull)
                    .anyMatch(s -> campaign.getEmployeeId().equals(s.getEmployeeId()));
            boolean recentlyVisitedProvider = atProvider.stream()
                    .filter(b -> b.getStatus() == BookingStatus.COMPLETED || b.getStatus() == BookingStatus.CONFIRMED)
                    .map(b -> providerSlotsById.get(b.getAvailabilitySlotId()))
                    .filter(Objects::nonNull)
                    .anyMatch(s -> !s.getStartsAt().isBefore(recentVisitCutoff) && !s.getStartsAt().isAfter(now));
            boolean categoryInterest = !categoryProviderIds.isEmpty() && everywhere.stream()
                    .map(b -> allSlotsById.get(b.getAvailabilitySlotId()))
                    .filter(Objects::nonNull)
                    .anyMatch(s -> !s.getProviderId().equals(providerId) && categoryProviderIds.contains(s.getProviderId()));
            boolean suitableHistoricalTime = everywhere.stream()
                    .map(b -> allSlotsById.get(b.getAvailabilitySlotId()))
                    .filter(Objects::nonNull)
                    .anyMatch(s -> minuteOfDayDistance(minuteOfDayUtc(s.getStartsAt()), slotMinuteOfDay)
                            <= scoring.suitableTimeToleranceMinutes());
            boolean recentEngagement = everywhere.stream().anyMatch(b -> !b.getCreatedAt().isBefore(recentEngagementCutoff));

            CandidateSignals signals = new CandidateSignals(followsProvider, previouslyBookedSameEmployee,
                    recentlyVisitedProvider, previouslyBookedSameService, previousProviderBooking, categoryInterest,
                    suitableHistoricalTime, recentEngagement);
            scored.add(candidateScorer.score(candidateId, signals));
        }

        return scored.stream()
                .filter(c -> c.score() > 0)
                .sorted(Comparator.comparingInt(ScoredCandidate::score).reversed().thenComparing(ScoredCandidate::userId))
                .limit(properties.staging().maxCandidatesPerCampaign())
                .toList();
    }

    private static int minuteOfDayUtc(Instant instant) {
        var time = instant.atZone(ZoneOffset.UTC).toLocalTime();
        return time.getHour() * 60 + time.getMinute();
    }

    private static int minuteOfDayDistance(int a, int b) {
        int diff = Math.abs(a - b);
        return Math.min(diff, 1440 - diff);
    }
}
