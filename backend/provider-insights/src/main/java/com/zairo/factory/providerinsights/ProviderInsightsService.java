package com.zairo.factory.providerinsights;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.payments.Payment;
import com.zairo.factory.payments.PaymentRepository;
import com.zairo.factory.payments.PaymentStatus;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.CustomerSummary;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.DashboardMetrics;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.DashboardMetrics.TopService;
import com.zairo.factory.providerinsights.ProviderInsightsDtos.PlatformBusinessOverview;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Read-only — computed fresh from {@code Booking}/{@code Payment} on every
 * call rather than persisted anywhere. Fine at today's scale (one owner's
 * bookings, not the whole platform's); worth revisiting only once a real
 * provider's booking history is large enough to make this slow, not before
 * (same "don't build ahead of real need" call the rest of this codebase
 * makes — see docs/adr/).
 */
@Service
public class ProviderInsightsService {

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final PaymentRepository paymentRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final UserRepository userRepository;
    private final ProviderRepository providerRepository;

    private static final int MAX_TOP_SERVICES = 5;

    public ProviderInsightsService(BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, PaymentRepository paymentRepository,
            ServiceOfferingRepository serviceOfferingRepository, UserRepository userRepository,
            ProviderRepository providerRepository) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.paymentRepository = paymentRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.userRepository = userRepository;
        this.providerRepository = providerRepository;
    }

    /** Newest-visited customer first; a customer with no completed visit yet sorts last. */
    public List<CustomerSummary> customerHistory(UUID providerId) {
        List<Booking> bookings = bookingRepository.findByProviderId(providerId);
        if (bookings.isEmpty()) {
            return List.of();
        }

        Map<UUID, List<Booking>> bookingsByUserId = bookings.stream().collect(Collectors.groupingBy(Booking::getUserId));

        Map<UUID, Instant> slotStartsAtBySlotId = availabilitySlotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, AvailabilitySlot::getStartsAt));

        Map<UUID, Payment> succeededPaymentByBookingId = paymentRepository
                .findByBookingIdInAndStatus(bookings.stream().map(Booking::getId).toList(), PaymentStatus.SUCCEEDED)
                .stream().collect(Collectors.toMap(Payment::getBookingId, payment -> payment));

        Map<UUID, String> serviceTitleByServiceId = serviceOfferingRepository
                .findAllById(bookings.stream().map(Booking::getServiceId).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, ServiceOffering::getTitle));

        Map<UUID, User> userById = userRepository.findAllById(new ArrayList<>(bookingsByUserId.keySet())).stream()
                .collect(Collectors.toMap(User::getId, user -> user));

        return bookingsByUserId.entrySet().stream()
                .map(entry -> summarize(entry.getKey(), entry.getValue(), slotStartsAtBySlotId,
                        succeededPaymentByBookingId, serviceTitleByServiceId, userById))
                .sorted(Comparator.comparing(CustomerSummary::lastVisitAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();
    }

    /** Owner contact, listed services and booking counts for the moderator's business card. */
    public PlatformBusinessOverview platformOverview(UUID providerId) {
        Provider provider = providerRepository.findById(providerId).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + providerId));
        User owner = userRepository.findById(provider.getOwnerUserId()).orElse(null);
        List<Booking> bookings = bookingRepository.findByProviderId(providerId);
        long completed = bookings.stream().filter(b -> b.getStatus() == BookingStatus.COMPLETED).count();
        return new PlatformBusinessOverview(providerId, owner == null ? null : owner.getDisplayName(),
                owner == null ? null : owner.getEmail(), owner == null ? null : owner.getPhone(),
                serviceOfferingRepository.findByProviderId(providerId).size(), bookings.size(), completed);
    }

    /** Revenue/booking-mix/top-services snapshot for this provider's admin dashboard. */
    public DashboardMetrics dashboardMetrics(UUID providerId) {
        List<Booking> bookings = bookingRepository.findByProviderId(providerId);

        long totalBookings = bookings.size();
        long completedBookings = bookings.stream().filter(b -> b.getStatus() == BookingStatus.COMPLETED).count();
        long cancelledBookings = bookings.stream().filter(b -> b.getStatus() == BookingStatus.CANCELLED).count();
        double cancellationRate = totalBookings == 0 ? 0.0 : (double) cancelledBookings / totalBookings;
        long totalCustomers = bookings.stream().map(Booking::getUserId).distinct().count();

        // Revenue is the value of the visits that took place (COMPLETED), however they were paid: a booking paid
        // at the venue earned money too, so counting only online payments showed "0" to owners who take cash.
        List<Booking> completed = bookings.stream().filter(b -> b.getStatus() == BookingStatus.COMPLETED).toList();
        BigDecimal totalRevenue = completed.stream().map(Booking::getTotalPrice).reduce(BigDecimal.ZERO,
                BigDecimal::add);
        String currency = completed.isEmpty() ? null : completed.get(0).getCurrency();
        BigDecimal averageCheck = completed.isEmpty() ? null
                : totalRevenue.divide(BigDecimal.valueOf(completed.size()), 2, RoundingMode.HALF_UP);

        Map<UUID, String> serviceTitleByServiceId = serviceOfferingRepository
                .findAllById(bookings.stream().map(Booking::getServiceId).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, ServiceOffering::getTitle));
        List<TopService> topServices = bookings.stream()
                .collect(Collectors.groupingBy(Booking::getServiceId, Collectors.counting())).entrySet().stream()
                .sorted(Map.Entry.<UUID, Long>comparingByValue().reversed())
                .limit(MAX_TOP_SERVICES)
                .map(entry -> new TopService(entry.getKey(), serviceTitleByServiceId.get(entry.getKey()), entry.getValue()))
                .toList();

        return new DashboardMetrics(providerId, totalBookings, completedBookings, cancelledBookings, cancellationRate,
                totalCustomers, totalRevenue, averageCheck, currency, topServices);
    }

    private CustomerSummary summarize(UUID userId, List<Booking> userBookings, Map<UUID, Instant> slotStartsAtBySlotId,
            Map<UUID, Payment> succeededPaymentByBookingId, Map<UUID, String> serviceTitleByServiceId,
            Map<UUID, User> userById) {
        int completedCount = (int) userBookings.stream().filter(b -> b.getStatus() == BookingStatus.COMPLETED).count();

        Instant lastVisitAt = userBookings.stream().filter(b -> b.getStatus() == BookingStatus.COMPLETED)
                .map(b -> slotStartsAtBySlotId.get(b.getAvailabilitySlotId())).filter(Objects::nonNull)
                .max(Comparator.naturalOrder()).orElse(null);

        List<Payment> succeededPayments = userBookings.stream().map(b -> succeededPaymentByBookingId.get(b.getId()))
                .filter(Objects::nonNull).toList();
        BigDecimal totalSpent = succeededPayments.stream().map(Payment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        String currency = succeededPayments.isEmpty() ? null : succeededPayments.get(0).getCurrency();

        String favoriteServiceTitle = userBookings.stream()
                .collect(Collectors.groupingBy(Booking::getServiceId, Collectors.counting())).entrySet().stream()
                .max(Map.Entry.comparingByValue()).map(Map.Entry::getKey).map(serviceTitleByServiceId::get)
                .orElse(null);

        User user = userById.get(userId);
        return new CustomerSummary(userId, user == null ? null : user.getDisplayName(),
                user == null ? null : user.getEmail(), userBookings.size(), completedCount, totalSpent, currency,
                lastVisitAt, favoriteServiceTitle);
    }
}
