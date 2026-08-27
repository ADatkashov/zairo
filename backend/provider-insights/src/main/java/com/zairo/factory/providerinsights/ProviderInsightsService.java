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
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

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

    public ProviderInsightsService(BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, PaymentRepository paymentRepository,
            ServiceOfferingRepository serviceOfferingRepository, UserRepository userRepository) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.paymentRepository = paymentRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.userRepository = userRepository;
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
