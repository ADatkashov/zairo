package com.zairo.factory.staff;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.staff.StaffOwnerDtos.NeedsAttentionResponse;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * The business owner's side of staff-related appointments: the "needs a decision" list and cancelling an
 * appointment. The owner (not the staff member) is the only one who may cancel with a refund.
 */
@Service
public class StaffOwnerService {

    private final ProviderOwnership providerOwnership;
    private final StaffBookingRepository staffBookingRepository;
    private final StaffRepository staffRepository;
    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final AvailabilitySlotRepository slotRepository;
    private final ServiceOfferingRepository serviceRepository;
    private final UserRepository userRepository;

    public StaffOwnerService(ProviderOwnership providerOwnership, StaffBookingRepository staffBookingRepository,
            StaffRepository staffRepository, BookingRepository bookingRepository, BookingService bookingService,
            AvailabilitySlotRepository slotRepository, ServiceOfferingRepository serviceRepository,
            UserRepository userRepository) {
        this.providerOwnership = providerOwnership;
        this.staffBookingRepository = staffBookingRepository;
        this.staffRepository = staffRepository;
        this.bookingRepository = bookingRepository;
        this.bookingService = bookingService;
        this.slotRepository = slotRepository;
        this.serviceRepository = serviceRepository;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public List<NeedsAttentionResponse> needsAttention(UUID providerId, UUID ownerId) {
        providerOwnership.requireOwner(providerId, ownerId);
        List<StaffBooking> declines = staffBookingRepository.findOpenDeclinesByProviderId(providerId);
        if (declines.isEmpty()) {
            return List.of();
        }
        Map<UUID, Booking> bookings = bookingRepository
                .findAllById(declines.stream().map(StaffBooking::getBookingId).toList()).stream()
                .collect(Collectors.toMap(Booking::getId, Function.identity()));
        Map<UUID, AvailabilitySlot> slots = slotRepository
                .findAllById(bookings.values().stream().map(Booking::getAvailabilitySlotId).distinct().toList())
                .stream().collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        Map<UUID, ServiceOffering> services = serviceRepository
                .findAllById(bookings.values().stream().map(Booking::getServiceId).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, Function.identity()));
        Map<UUID, User> customers = userRepository
                .findAllById(bookings.values().stream().map(Booking::getUserId).distinct().toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        Map<UUID, Staff> staff = staffRepository
                .findAllById(declines.stream().map(StaffBooking::getStaffId).distinct().toList()).stream()
                .collect(Collectors.toMap(Staff::getId, Function.identity()));

        List<NeedsAttentionResponse> result = new ArrayList<>();
        for (StaffBooking decline : declines) {
            Booking booking = bookings.get(decline.getBookingId());
            AvailabilitySlot slot = booking == null ? null : slots.get(booking.getAvailabilitySlotId());
            if (booking == null || slot == null) {
                continue;
            }
            ServiceOffering service = services.get(booking.getServiceId());
            User customer = customers.get(booking.getUserId());
            Staff member = staff.get(decline.getStaffId());
            result.add(new NeedsAttentionResponse(booking.getId(), booking.getStatus().name(), slot.getStartsAt(),
                    slot.getEndsAt(), booking.getServiceId(), service == null ? null : service.getTitle(),
                    customer == null ? null : customer.getDisplayName(),
                    customer == null ? null : customer.getPhone(), booking.getTotalPrice(), booking.getCurrency(),
                    decline.getStaffId(), member == null ? null : member.getDisplayName(), "STAFF_CANNOT_ATTEND",
                    decline.getStaffDeclineReason(), decline.getStaffDeclinedAt()));
        }
        result.sort(Comparator.comparing(NeedsAttentionResponse::startsAt));
        return result;
    }

    /** Cancel an appointment of this business: slot released, a paid booking refunded, customer notified. */
    @Transactional
    public void cancel(UUID providerId, UUID bookingId, UUID ownerId, String reason) {
        providerOwnership.requireOwner(providerId, ownerId);
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        AvailabilitySlot slot = slotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Slot not found"));
        if (!providerId.equals(slot.getProviderId())) {
            // Reported as not found: don't reveal that the booking exists at another business.
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: " + bookingId);
        }
        bookingService.cancelBookingAuthorized(bookingId, reason == null || reason.isBlank() ? null : reason.trim());
    }
}
