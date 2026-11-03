package com.zairo.factory.providerinsights;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.customerintelligence.CustomerProviderProfile;
import com.zairo.factory.customerintelligence.CustomerProviderProfileRepository;
import com.zairo.factory.customerintelligence.RetentionStatus;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.ActionCenterResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.ActionItem;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.ActionItemType;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.BookingAnalyticsResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.BookingAnalyticsResponse.DailyBookingCount;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.CustomerAnalyticsResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.CustomerAnalyticsResponse.FavouriteService;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.CustomerAnalyticsResponse.FavouriteStaff;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.CustomerListItem;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.OverviewResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.RevenueAnalyticsResponse;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.RevenueAnalyticsResponse.DailyAmount;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.RevenueAnalyticsResponse.ServiceRevenue;
import com.zairo.factory.providerinsights.BusinessAnalyticsDtos.RevenueAnalyticsResponse.StaffRevenue;
import com.zairo.factory.revenueengine.RevenueAttributionService;
import com.zairo.factory.revenueengine.RevenueEngineDtos.RevenueSummaryResponse;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.smartfill.SmartFillAnalyticsService;
import com.zairo.factory.smartfill.SmartFillCampaign;
import com.zairo.factory.smartfill.SmartFillCampaignRepository;
import com.zairo.factory.smartfill.SmartFillCampaignStatus;
import com.zairo.factory.smartfill.SmartFillDtos.SmartFillPerformanceResponse;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * The Business Intelligence Dashboard's read composition layer — same
 * "computed fresh on every call, no persisted aggregate table" discipline
 * as {@link ProviderInsightsService}, just scoped to a caller-chosen
 * reporting period instead of a provider's entire history. Reuses Smart
 * Fill's and Revenue Engine's own analytics rather than recomputing either
 * (see {@link SmartFillAnalyticsService#performance(UUID, Instant, Instant)}
 * and {@link RevenueAttributionService#summary(UUID, Instant, Instant)}),
 * and reads Customer Intelligence's already-computed per-business profiles
 * rather than recalculating retention/value from booking history itself.
 */
@Service
public class BusinessAnalyticsService {

    /** Below this booked/offered ratio, a near-term day is flagged as a low-utilization Action Center item. */
    private static final double LOW_UTILIZATION_THRESHOLD = 0.3;
    private static final int MAX_REVENUE_BREAKDOWN_ROWS = 10;
    private static final int MAX_FAVOURITES = 5;
    private static final ZoneOffset REPORTING_ZONE = ZoneOffset.UTC;

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final CustomerProviderProfileRepository customerProviderProfileRepository;
    private final SmartFillCampaignRepository smartFillCampaignRepository;
    private final SmartFillAnalyticsService smartFillAnalyticsService;
    private final RevenueAttributionService revenueAttributionService;
    private final UserRepository userRepository;
    private final Clock clock;

    public BusinessAnalyticsService(BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository,
            ServiceOfferingRepository serviceOfferingRepository,
            CustomerProviderProfileRepository customerProviderProfileRepository,
            SmartFillCampaignRepository smartFillCampaignRepository,
            SmartFillAnalyticsService smartFillAnalyticsService, RevenueAttributionService revenueAttributionService,
            UserRepository userRepository, Clock clock) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.customerProviderProfileRepository = customerProviderProfileRepository;
        this.smartFillCampaignRepository = smartFillCampaignRepository;
        this.smartFillAnalyticsService = smartFillAnalyticsService;
        this.revenueAttributionService = revenueAttributionService;
        this.userRepository = userRepository;
        this.clock = clock;
    }

    public OverviewResponse overview(UUID providerId, Instant from, Instant to) {
        Range range = resolveRange(from, to);

        BookingAnalyticsResponse bookingStats = bookings(providerId, range.from(), range.to());
        RevenueAnalyticsResponse revenueStats = revenue(providerId, range.from(), range.to());
        Double utilization = utilization(providerId, range.from(), range.to());
        double returningCustomerRate = returningCustomerRate(providerId);

        return new OverviewResponse(providerId, range.from(), range.to(), bookingStats.totalBookings(),
                bookingStats.completedBookings(), bookingStats.upcomingBookings(), bookingStats.cancelledBookings(),
                bookingStats.noShowBookings(), bookingStats.cancellationRate(), bookingStats.noShowRate(),
                revenueStats.totalRevenue(), revenueStats.averageBookingValue(), revenueStats.currency(),
                utilization, returningCustomerRate, revenueStats.revenueRecovered(),
                revenueStats.revenueRecoveredCurrency());
    }

    public RevenueAnalyticsResponse revenue(UUID providerId, Instant from, Instant to) {
        Range range = resolveRange(from, to);

        List<Booking> bookings = bookingRepository.findByProviderIdAndSlotStartsAtBetween(providerId, range.from(),
                range.to());
        Map<UUID, AvailabilitySlot> slotById = slotById(bookings);
        // Revenue is the value of the visits that took place (COMPLETED), however they were paid: a booking paid at
        // the venue earned money too, so counting only online payments showed "0" to owners who take cash.
        List<Booking> paidBookings = bookings.stream().filter(b -> b.getStatus() == BookingStatus.COMPLETED)
                .toList();

        BigDecimal totalRevenue = paidBookings.stream().map(Booking::getTotalPrice).reduce(BigDecimal.ZERO,
                BigDecimal::add);
        String currency = paidBookings.isEmpty() ? null : paidBookings.get(0).getCurrency();
        BigDecimal averageBookingValue = paidBookings.isEmpty() ? null
                : totalRevenue.divide(BigDecimal.valueOf(paidBookings.size()), 2, RoundingMode.HALF_UP);

        Map<LocalDate, BigDecimal> byDay = new TreeMap<>();
        for (Booking booking : paidBookings) {
            AvailabilitySlot slot = slotById.get(booking.getAvailabilitySlotId());
            if (slot == null) {
                continue;
            }
            LocalDate date = LocalDate.ofInstant(slot.getStartsAt(), REPORTING_ZONE);
            byDay.merge(date, booking.getTotalPrice(), BigDecimal::add);
        }
        List<DailyAmount> revenueByDay = byDay.entrySet().stream()
                .map(e -> new DailyAmount(e.getKey(), e.getValue())).toList();

        Map<UUID, String> serviceTitleById = serviceOfferingRepository
                .findAllById(paidBookings.stream().map(Booking::getServiceId).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, ServiceOffering::getTitle));
        Map<UUID, List<Booking>> byService = paidBookings.stream()
                .collect(Collectors.groupingBy(Booking::getServiceId));
        List<ServiceRevenue> revenueByService = byService.entrySet().stream()
                .map(e -> new ServiceRevenue(e.getKey(), serviceTitleById.get(e.getKey()),
                        sumPrices(e.getValue()), e.getValue().size()))
                .sorted(Comparator.comparing(ServiceRevenue::amount).reversed())
                .limit(MAX_REVENUE_BREAKDOWN_ROWS)
                .toList();

        // Bookings on a shared (not person-specific) slot have no employee and belong to no staff row.
        Map<UUID, List<Booking>> byStaff = paidBookings.stream()
                .filter(b -> employeeIdOf(b, slotById) != null)
                .collect(Collectors.groupingBy(b -> employeeIdOf(b, slotById)));
        List<StaffRevenue> revenueByStaff = byStaff.entrySet().stream()
                .map(e -> new StaffRevenue(e.getKey(), sumPrices(e.getValue()),
                        e.getValue().size()))
                .sorted(Comparator.comparing(StaffRevenue::amount).reversed())
                .limit(MAX_REVENUE_BREAKDOWN_ROWS)
                .toList();

        RevenueSummaryResponse recovered = revenueAttributionService.summary(providerId, range.from(), range.to());

        return new RevenueAnalyticsResponse(providerId, range.from(), range.to(), totalRevenue, currency,
                averageBookingValue, revenueByDay, revenueByService, revenueByStaff, recovered.totalRecovered(),
                recovered.currency());
    }

    public BookingAnalyticsResponse bookings(UUID providerId, Instant from, Instant to) {
        Range range = resolveRange(from, to);

        List<Booking> bookings = bookingRepository.findByProviderIdAndSlotStartsAtBetween(providerId, range.from(),
                range.to());
        Map<UUID, AvailabilitySlot> slotById = slotById(bookings);
        Instant now = clock.instant();

        long total = bookings.size();
        long completed = countByStatus(bookings, BookingStatus.COMPLETED);
        long cancelled = countByStatus(bookings, BookingStatus.CANCELLED);
        long noShow = countByStatus(bookings, BookingStatus.NO_SHOW);
        long upcoming = bookings.stream()
                .filter(b -> b.getStatus() == BookingStatus.CONFIRMED)
                .filter(b -> {
                    AvailabilitySlot slot = slotById.get(b.getAvailabilitySlotId());
                    return slot != null && slot.getStartsAt().isAfter(now);
                })
                .count();
        double cancellationRate = total == 0 ? 0.0 : (double) cancelled / total;
        double noShowRate = total == 0 ? 0.0 : (double) noShow / total;

        Map<UUID, List<Booking>> byCustomer = bookings.stream().collect(Collectors.groupingBy(Booking::getUserId));
        long distinctCustomers = byCustomer.size();
        long repeatCustomers = byCustomer.values().stream().filter(list -> list.size() > 1).count();
        double repeatBookingRate = distinctCustomers == 0 ? 0.0 : (double) repeatCustomers / distinctCustomers;

        Map<LocalDate, List<Booking>> byDay = bookings.stream()
                .filter(b -> slotById.containsKey(b.getAvailabilitySlotId()))
                .collect(Collectors.groupingBy(
                        b -> LocalDate.ofInstant(slotById.get(b.getAvailabilitySlotId()).getStartsAt(), REPORTING_ZONE),
                        TreeMap::new, Collectors.toList()));
        List<DailyBookingCount> trend = byDay.entrySet().stream()
                .map(e -> new DailyBookingCount(e.getKey(), e.getValue().size(),
                        countByStatus(e.getValue(), BookingStatus.COMPLETED),
                        countByStatus(e.getValue(), BookingStatus.CANCELLED),
                        countByStatus(e.getValue(), BookingStatus.NO_SHOW)))
                .toList();

        return new BookingAnalyticsResponse(providerId, range.from(), range.to(), total, completed, upcoming,
                cancelled, noShow, cancellationRate, noShowRate, repeatBookingRate, trend);
    }

    public CustomerAnalyticsResponse customers(UUID providerId, Instant from, Instant to) {
        Range range = resolveRange(from, to);

        List<CustomerProviderProfile> profiles = customerProviderProfileRepository.findByProviderId(providerId);

        long total = profiles.size();
        long active = countByRetention(profiles, RetentionStatus.ACTIVE);
        long returning = profiles.stream().filter(p -> p.getCompletedBookings() > 1).count();
        long newCustomers = profiles.stream()
                .filter(p -> p.getFirstVisitAt() != null && !p.getFirstVisitAt().isBefore(range.from())
                        && p.getFirstVisitAt().isBefore(range.to()))
                .count();
        long dueForRebooking = countByRetention(profiles, RetentionStatus.DUE_FOR_REBOOKING);
        long atRisk = countByRetention(profiles, RetentionStatus.AT_RISK);
        long inactive = countByRetention(profiles, RetentionStatus.INACTIVE);

        List<Integer> intervals = profiles.stream().map(CustomerProviderProfile::getAverageVisitIntervalDays)
                .filter(Objects::nonNull).toList();
        Double averageVisitIntervalDays = intervals.isEmpty() ? null
                : intervals.stream().mapToInt(Integer::intValue).average().orElse(0.0);

        List<CustomerProviderProfile> spendingProfiles = profiles.stream().filter(p -> p.getTotalBookings() > 0)
                .toList();
        BigDecimal averageCustomerValue = spendingProfiles.isEmpty() ? null
                : spendingProfiles.stream().map(CustomerProviderProfile::getTotalSpent)
                        .reduce(BigDecimal.ZERO, BigDecimal::add)
                        .divide(BigDecimal.valueOf(spendingProfiles.size()), 2, RoundingMode.HALF_UP);
        String currency = spendingProfiles.stream().map(CustomerProviderProfile::getCurrency)
                .filter(Objects::nonNull).findFirst().orElse(null);

        Map<UUID, Long> byService = profiles.stream().filter(p -> p.getFavouriteServiceId() != null)
                .collect(Collectors.groupingBy(CustomerProviderProfile::getFavouriteServiceId, Collectors.counting()));
        Map<UUID, String> serviceTitleById = serviceOfferingRepository.findAllById(byService.keySet()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, ServiceOffering::getTitle));
        List<FavouriteService> favouriteServices = byService.entrySet().stream()
                .sorted(Map.Entry.<UUID, Long>comparingByValue().reversed())
                .limit(MAX_FAVOURITES)
                .map(e -> new FavouriteService(e.getKey(), serviceTitleById.get(e.getKey()), e.getValue()))
                .toList();

        Map<UUID, Long> byStaff = profiles.stream().filter(p -> p.getFavouriteEmployeeId() != null)
                .collect(Collectors.groupingBy(CustomerProviderProfile::getFavouriteEmployeeId,
                        Collectors.counting()));
        List<FavouriteStaff> favouriteStaff = byStaff.entrySet().stream()
                .sorted(Map.Entry.<UUID, Long>comparingByValue().reversed())
                .limit(MAX_FAVOURITES)
                .map(e -> new FavouriteStaff(e.getKey(), e.getValue()))
                .toList();

        return new CustomerAnalyticsResponse(providerId, range.from(), range.to(), total, active, returning,
                newCustomers, dueForRebooking, atRisk, inactive, averageVisitIntervalDays, averageCustomerValue,
                currency, favouriteServices, favouriteStaff);
    }

    /**
     * The individual customers behind one of {@link #customers}'s counts --
     * the Action Center's "rebook opportunity"/"retention risk" drill-down
     * (see {@code providerinsights.ProviderInsightsController}). Oldest
     * last-visit first when a filter is given (the most overdue customer
     * first), since that's the one who most needs the owner's attention;
     * unfiltered, newest-visited first, matching {@link
     * ProviderInsightsService#customerHistory}. Not date-scoped, same
     * "current relationship state" reasoning as {@link #customers}'s own
     * (non-"new customers") fields.
     */
    public List<CustomerListItem> customersList(UUID providerId, RetentionStatus retentionStatus) {
        List<CustomerProviderProfile> profiles = customerProviderProfileRepository.findByProviderId(providerId);
        List<CustomerProviderProfile> filtered = retentionStatus == null ? profiles
                : profiles.stream().filter(p -> p.getRetentionStatus() == retentionStatus).toList();
        if (filtered.isEmpty()) {
            return List.of();
        }

        Map<UUID, User> userById = userRepository
                .findAllById(filtered.stream().map(CustomerProviderProfile::getUserId).distinct().toList()).stream()
                .collect(Collectors.toMap(User::getId, user -> user));
        Map<UUID, String> serviceTitleById = serviceOfferingRepository
                .findAllById(filtered.stream().map(CustomerProviderProfile::getFavouriteServiceId)
                        .filter(Objects::nonNull).distinct().toList())
                .stream().collect(Collectors.toMap(ServiceOffering::getId, ServiceOffering::getTitle));

        Comparator<CustomerProviderProfile> order = retentionStatus == null
                ? Comparator.comparing(CustomerProviderProfile::getLastVisitAt, Comparator.nullsLast(Comparator.reverseOrder()))
                : Comparator.comparing(CustomerProviderProfile::getLastVisitAt, Comparator.nullsLast(Comparator.naturalOrder()));

        return filtered.stream().sorted(order)
                .map(profile -> {
                    User user = userById.get(profile.getUserId());
                    return new CustomerListItem(profile.getUserId(), user == null ? null : user.getDisplayName(),
                            user == null ? null : user.getEmail(), profile.getRetentionStatus(),
                            profile.getLastVisitAt(), profile.getNextExpectedVisitAt(), profile.getTotalSpent(),
                            profile.getCurrency(),
                            profile.getFavouriteServiceId() == null ? null
                                    : serviceTitleById.get(profile.getFavouriteServiceId()),
                            profile.getNoShows());
                })
                .toList();
    }

    /** Smart Fill's own performance snapshot, scoped to the same reporting period as the rest of this dashboard. */
    public SmartFillPerformanceResponse smartFillPerformance(UUID providerId, Instant from, Instant to) {
        Range range = resolveRange(from, to);
        return smartFillAnalyticsService.performance(providerId, range.from(), range.to());
    }

    /**
     * Deterministic, rule-based signals — never a generated recommendation.
     * Not date-scoped: this is "what needs attention right now", not a
     * historical report.
     */
    public ActionCenterResponse actions(UUID providerId) {
        List<ActionItem> items = new ArrayList<>();
        Instant now = clock.instant();

        long activeSmartFillCampaigns = smartFillCampaignRepository.findByProviderId(providerId).stream()
                .map(SmartFillCampaign::getStatus)
                .filter(status -> status == SmartFillCampaignStatus.CREATED
                        || status == SmartFillCampaignStatus.SEARCHING
                        || status == SmartFillCampaignStatus.NOTIFYING)
                .count();
        if (activeSmartFillCampaigns > 0) {
            items.add(new ActionItem(ActionItemType.SMART_FILL_OPPORTUNITY, activeSmartFillCampaigns));
        }

        List<CustomerProviderProfile> profiles = customerProviderProfileRepository.findByProviderId(providerId);
        long dueForRebooking = countByRetention(profiles, RetentionStatus.DUE_FOR_REBOOKING);
        if (dueForRebooking > 0) {
            items.add(new ActionItem(ActionItemType.REBOOK_OPPORTUNITY, dueForRebooking));
        }
        long atRisk = countByRetention(profiles, RetentionStatus.AT_RISK);
        if (atRisk > 0) {
            items.add(new ActionItem(ActionItemType.RETENTION_RISK, atRisk));
        }

        List<AvailabilitySlot> tomorrowSlots = availabilitySlotRepository
                .findByProviderIdAndStartsAtBetween(providerId, now, now.plus(Duration.ofDays(1)));
        if (!tomorrowSlots.isEmpty()) {
            long bookedCount = tomorrowSlots.stream().filter(s -> s.getStatus() == AvailabilityStatus.BOOKED).count();
            double ratio = (double) bookedCount / tomorrowSlots.size();
            if (ratio < LOW_UTILIZATION_THRESHOLD) {
                items.add(new ActionItem(ActionItemType.LOW_UTILIZATION, tomorrowSlots.size() - bookedCount));
            }
        }

        return new ActionCenterResponse(providerId, items);
    }

    private Double utilization(UUID providerId, Instant from, Instant to) {
        List<AvailabilitySlot> slots = availabilitySlotRepository.findByProviderIdAndStartsAtBetween(providerId, from,
                to);
        if (slots.isEmpty()) {
            return null;
        }
        long totalMinutes = slots.stream().mapToLong(s -> Duration.between(s.getStartsAt(), s.getEndsAt()).toMinutes())
                .sum();
        if (totalMinutes == 0) {
            return null;
        }
        long bookedMinutes = slots.stream().filter(s -> s.getStatus() == AvailabilityStatus.BOOKED)
                .mapToLong(s -> Duration.between(s.getStartsAt(), s.getEndsAt()).toMinutes()).sum();
        return (double) bookedMinutes / totalMinutes;
    }

    private double returningCustomerRate(UUID providerId) {
        List<CustomerProviderProfile> profiles = customerProviderProfileRepository.findByProviderId(providerId);
        if (profiles.isEmpty()) {
            return 0.0;
        }
        long returning = profiles.stream().filter(p -> p.getCompletedBookings() > 1).count();
        return (double) returning / profiles.size();
    }

    private Map<UUID, AvailabilitySlot> slotById(List<Booking> bookings) {
        return availabilitySlotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, s -> s));
    }

    private static UUID employeeIdOf(Booking booking, Map<UUID, AvailabilitySlot> slotById) {
        AvailabilitySlot slot = slotById.get(booking.getAvailabilitySlotId());
        return slot == null ? null : slot.getEmployeeId();
    }

    private static BigDecimal sumPrices(List<Booking> bookings) {
        return bookings.stream().map(Booking::getTotalPrice).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static long countByStatus(List<Booking> bookings, BookingStatus status) {
        return bookings.stream().filter(b -> b.getStatus() == status).count();
    }

    private static long countByRetention(List<CustomerProviderProfile> profiles, RetentionStatus status) {
        return profiles.stream().filter(p -> p.getRetentionStatus() == status).count();
    }

    private record Range(Instant from, Instant to) {
    }

    /** Defaults to the current calendar month (UTC) through now if either bound is omitted. */
    private Range resolveRange(Instant from, Instant to) {
        Instant effectiveFrom = from != null ? from
                : LocalDate.now(clock.withZone(REPORTING_ZONE)).withDayOfMonth(1).atStartOfDay(REPORTING_ZONE)
                        .toInstant();
        Instant effectiveTo = to != null ? to : clock.instant();
        if (!effectiveFrom.isBefore(effectiveTo)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "'from' must be before 'to'");
        }
        return new Range(effectiveFrom, effectiveTo);
    }
}
