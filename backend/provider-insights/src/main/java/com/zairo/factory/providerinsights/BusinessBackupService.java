package com.zairo.factory.providerinsights;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.customerintelligence.CustomerProviderProfile;
import com.zairo.factory.customerintelligence.CustomerProviderProfileRepository;
import com.zairo.factory.providerinsights.BusinessBackupDtos.BackupResponse;
import com.zairo.factory.providerinsights.BusinessBackupDtos.BookingRow;
import com.zairo.factory.providerinsights.BusinessBackupDtos.CustomerRow;
import com.zairo.factory.providerinsights.BusinessBackupDtos.ServiceRow;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.staff.Staff;
import com.zairo.factory.staff.StaffRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Composes the owner's "keep a copy" file from data other modules already own — read-only, nothing stored. A
 * booking is listed with its customer's name and contact even though the live schedule endpoint leaves those out,
 * because the point of the copy is being able to phone the person when the app cannot tell you who it is.
 */
@Service
public class BusinessBackupService {

    /** How far back the default window starts: recent history, in case a visit needs checking. */
    static final Duration DEFAULT_LOOK_BACK = Duration.ofDays(30);
    /** How far ahead the default window reaches: every booking an ordinary calendar already holds. */
    static final Duration DEFAULT_LOOK_AHEAD = Duration.ofDays(180);
    static final Duration MAX_WINDOW = Duration.ofDays(400);

    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final StaffRepository staffRepository;
    private final UserRepository userRepository;
    private final CustomerProviderProfileRepository customerProviderProfileRepository;
    private final Clock clock;

    public BusinessBackupService(BookingRepository bookingRepository,
            AvailabilitySlotRepository availabilitySlotRepository, ServiceOfferingRepository serviceOfferingRepository,
            StaffRepository staffRepository, UserRepository userRepository,
            CustomerProviderProfileRepository customerProviderProfileRepository, Clock clock) {
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.staffRepository = staffRepository;
        this.userRepository = userRepository;
        this.customerProviderProfileRepository = customerProviderProfileRepository;
        this.clock = clock;
    }

    /** [from, to] default to the window described on the constants when null. */
    public BackupResponse backup(UUID providerId, Instant from, Instant to) {
        Instant now = clock.instant();
        Instant start = from != null ? from : now.minus(DEFAULT_LOOK_BACK);
        Instant end = to != null ? to : now.plus(DEFAULT_LOOK_AHEAD);
        if (!start.isBefore(end) || Duration.between(start, end).compareTo(MAX_WINDOW) > 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "`from` must be before `to`, at most 400 days apart");
        }

        List<Booking> bookings = bookingRepository.findByProviderIdAndSlotStartsAtBetween(providerId, start, end);
        Map<UUID, AvailabilitySlot> slotById = availabilitySlotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        List<ServiceOffering> offerings = serviceOfferingRepository.findByProviderId(providerId);
        Map<UUID, String> serviceTitleById = offerings.stream()
                .collect(Collectors.toMap(ServiceOffering::getId, ServiceOffering::getTitle));
        Map<UUID, String> staffNameById = staffRepository.findByProviderId(providerId).stream()
                .collect(Collectors.toMap(Staff::getId, Staff::getDisplayName));
        List<CustomerProviderProfile> profiles = customerProviderProfileRepository.findByProviderId(providerId);

        Set<UUID> userIds = new HashSet<>();
        bookings.forEach(b -> userIds.add(b.getUserId()));
        profiles.forEach(p -> userIds.add(p.getUserId()));
        Map<UUID, User> userById = userRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        List<BookingRow> bookingRows = bookings.stream()
                .filter(b -> slotById.containsKey(b.getAvailabilitySlotId()))
                .sorted(Comparator.comparing((Booking b) -> slotById.get(b.getAvailabilitySlotId()).getStartsAt()))
                .map(b -> {
                    AvailabilitySlot slot = slotById.get(b.getAvailabilitySlotId());
                    User customer = userById.get(b.getUserId());
                    return new BookingRow(b.getId(), slot.getStartsAt(), slot.getEndsAt(), b.getStatus().name(),
                            serviceTitleById.get(b.getServiceId()),
                            slot.getEmployeeId() == null ? null : staffNameById.get(slot.getEmployeeId()),
                            customer == null ? null : customer.getDisplayName(),
                            customer == null ? null : customer.getPhone(),
                            customer == null ? null : customer.getEmail(), b.getTotalPrice(), b.getCurrency());
                })
                .toList();

        List<CustomerRow> customerRows = profiles.stream()
                .sorted(Comparator.comparing(CustomerProviderProfile::getLastVisitAt,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .map(p -> {
                    User user = userById.get(p.getUserId());
                    return new CustomerRow(p.getUserId(), user == null ? null : user.getDisplayName(),
                            user == null ? null : user.getPhone(), user == null ? null : user.getEmail(),
                            p.getLastVisitAt(), p.getTotalBookings(), p.getTotalSpent(), p.getCurrency(),
                            p.getNoShows());
                })
                .toList();

        List<ServiceRow> serviceRows = offerings.stream()
                .sorted(Comparator.comparing(ServiceOffering::getTitle, String.CASE_INSENSITIVE_ORDER))
                .map(o -> new ServiceRow(o.getTitle(), o.getDurationMinutes(), o.getPrice(), o.getCurrency(),
                        o.isActive()))
                .toList();

        return new BackupResponse(providerId, now, start, end, bookingRows, customerRows, serviceRows);
    }
}
