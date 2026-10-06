package com.zairo.factory.staff;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.reviews.Review;
import com.zairo.factory.reviews.ReviewRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.staff.StaffPortalDtos.StaffAppointmentResponse;
import com.zairo.factory.staff.StaffPortalDtos.StaffMembershipResponse;
import com.zairo.factory.staff.StaffPortalDtos.StaffRatingResponse;
import com.zairo.factory.staff.StaffPortalDtos.StaffReviewResponse;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
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
 * The staff member's own cabinet. A person can work at several businesses (one {@link Staff} row per business,
 * linked by {@code user_id}); every call is scoped to one of the caller's own staff rows, so a staff member sees
 * and acts on exactly the appointments booked with them — never a colleague's, never the business's whole book.
 *
 * <p>Acting on a booking goes through core {@link BookingService}'s {@code *Authorized} methods, so the state
 * rules, slot release, refund and notification events stay identical to the owner and customer flows; only the
 * "who may do it" check differs and is done here.
 */
@Service
public class StaffPortalService {

    public enum Scope {
        ALL, UPCOMING, HISTORY
    }

    private static final int MAX_REVIEWS = 100;

    private final StaffRepository staffRepository;
    private final StaffBookingRepository staffBookingRepository;
    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final AvailabilitySlotRepository slotRepository;
    private final ServiceOfferingRepository serviceRepository;
    private final ProviderRepository providerRepository;
    private final UserRepository userRepository;
    private final ReviewRepository reviewRepository;

    public StaffPortalService(StaffRepository staffRepository, StaffBookingRepository staffBookingRepository,
            BookingRepository bookingRepository, BookingService bookingService,
            AvailabilitySlotRepository slotRepository, ServiceOfferingRepository serviceRepository,
            ProviderRepository providerRepository, UserRepository userRepository,
            ReviewRepository reviewRepository) {
        this.staffRepository = staffRepository;
        this.staffBookingRepository = staffBookingRepository;
        this.bookingRepository = bookingRepository;
        this.bookingService = bookingService;
        this.slotRepository = slotRepository;
        this.serviceRepository = serviceRepository;
        this.providerRepository = providerRepository;
        this.userRepository = userRepository;
        this.reviewRepository = reviewRepository;
    }

    @Transactional(readOnly = true)
    public List<StaffMembershipResponse> memberships(UUID userId) {
        Instant now = Instant.now();
        List<StaffMembershipResponse> result = new ArrayList<>();
        for (Staff staff : staffRepository.findByUserId(userId)) {
            Provider provider = providerRepository.findById(staff.getProviderId()).orElse(null);
            if (provider == null) {
                continue;
            }
            List<Entry> entries = entries(staff.getId());
            int pending = (int) entries.stream().filter(e -> e.needsAcceptance(now)).count();
            List<Review> reviews = reviewsOf(entries);
            Double average = reviews.isEmpty() ? null
                    : reviews.stream().mapToInt(Review::getRating).average().orElse(0);
            result.add(new StaffMembershipResponse(staff.getId(), provider.getId(), provider.getName(),
                    staff.getDisplayName(), staff.getPhotoUrl(), staff.isActive(), pending, average,
                    reviews.size()));
        }
        result.sort(Comparator.comparing(StaffMembershipResponse::providerName, String.CASE_INSENSITIVE_ORDER));
        return result;
    }

    @Transactional(readOnly = true)
    public List<StaffAppointmentResponse> appointments(UUID userId, UUID staffId, Scope scope) {
        requireOwnStaff(staffId, userId);
        Instant now = Instant.now();
        List<Entry> entries = entries(staffId).stream()
                .filter(e -> switch (scope) {
                    case ALL -> true;
                    case UPCOMING -> e.isUpcoming(now);
                    case HISTORY -> !e.isUpcoming(now);
                })
                .toList();

        Map<UUID, ServiceOffering> services = serviceRepository
                .findAllById(entries.stream().map(e -> e.booking.getServiceId()).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, Function.identity()));
        Map<UUID, User> customers = userRepository
                .findAllById(entries.stream().map(e -> e.booking.getUserId()).distinct().toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        // Upcoming soonest first; history (and "all") newest first.
        Comparator<Entry> byStart = Comparator.comparing(e -> e.slot.getStartsAt());
        List<Entry> sorted = new ArrayList<>(entries);
        sorted.sort(scope == Scope.UPCOMING ? byStart : byStart.reversed());

        return sorted.stream().map(e -> {
            ServiceOffering service = services.get(e.booking.getServiceId());
            User customer = customers.get(e.booking.getUserId());
            BookingStatus status = e.booking.getStatus();
            boolean confirmed = status == BookingStatus.CONFIRMED;
            return new StaffAppointmentResponse(e.booking.getId(), status.name(), e.slot.getStartsAt(),
                    e.slot.getEndsAt(), e.booking.getServiceId(), service == null ? null : service.getTitle(),
                    customer == null ? null : customer.getDisplayName(), customer == null ? null
                            : customer.getPhone(),
                    e.booking.getTotalPrice(), e.booking.getCurrency(), e.booking.getPaidAmount(),
                    e.booking.getCancellationReason(), e.confirmedAt(), confirmed && e.confirmedAt() == null,
                    confirmed || status == BookingStatus.PENDING_PAYMENT, confirmed, confirmed);
        }).toList();
    }

    /** The staff member accepts an appointment: purely an acknowledgement, the booking's status is unchanged. */
    @Transactional
    public void accept(UUID userId, UUID staffId, UUID bookingId) {
        requireOwnActiveStaff(staffId, userId);
        Booking booking = requireOwnBooking(staffId, bookingId);
        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Only a confirmed appointment can be accepted (status=" + booking.getStatus() + ")");
        }
        StaffBooking link = staffBookingRepository.findByBookingId(bookingId)
                .orElseGet(() -> new StaffBooking(UUID.randomUUID(), bookingId, staffId, Instant.now()));
        link.confirmByStaff(Instant.now());
        staffBookingRepository.save(link);
    }

    /** The staff member cancels an appointment: slot released, customer refunded and notified. */
    @Transactional
    public void cancel(UUID userId, UUID staffId, UUID bookingId, String reason) {
        requireOwnActiveStaff(staffId, userId);
        requireOwnBooking(staffId, bookingId);
        bookingService.cancelBookingAuthorized(bookingId, reason);
    }

    @Transactional
    public void complete(UUID userId, UUID staffId, UUID bookingId) {
        requireOwnActiveStaff(staffId, userId);
        requireOwnBooking(staffId, bookingId);
        bookingService.completeBookingAuthorized(bookingId);
    }

    @Transactional
    public void markNoShow(UUID userId, UUID staffId, UUID bookingId) {
        requireOwnActiveStaff(staffId, userId);
        requireOwnBooking(staffId, bookingId);
        bookingService.markNoShowAuthorized(bookingId);
    }

    @Transactional(readOnly = true)
    public StaffRatingResponse rating(UUID userId, UUID staffId) {
        requireOwnStaff(staffId, userId);
        List<Entry> entries = entries(staffId);
        List<Review> reviews = reviewsOf(entries);
        long[] counts = new long[5];
        for (Review review : reviews) {
            if (review.getRating() >= 1 && review.getRating() <= 5) {
                counts[review.getRating() - 1]++;
            }
        }
        Double average = reviews.isEmpty() ? null : reviews.stream().mapToInt(Review::getRating).average().orElse(0);

        Map<UUID, Booking> bookingsById = entries.stream()
                .collect(Collectors.toMap(e -> e.booking.getId(), e -> e.booking));
        List<Review> latest = reviews.stream()
                .sorted(Comparator.comparing(Review::getCreatedAt).reversed()).limit(MAX_REVIEWS).toList();
        Map<UUID, User> customers = userRepository.findAllById(latest.stream()
                .map(r -> bookingsById.get(r.getBookingId()).getUserId()).distinct().toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        List<StaffReviewResponse> rows = latest.stream().map(r -> {
            User customer = customers.get(bookingsById.get(r.getBookingId()).getUserId());
            return new StaffReviewResponse(r.getId(), r.getBookingId(),
                    customer == null ? null : customer.getDisplayName(), r.getRating(), r.getComment(),
                    r.getCreatedAt(), r.getBusinessReply(), r.getBusinessReplyAt());
        }).toList();
        return new StaffRatingResponse(average, reviews.size(),
                java.util.Arrays.stream(counts).boxed().toList(), rows);
    }

    // --- internals ---

    /** A booking of this staff member together with its slot and (if any) the staff acceptance link. */
    private record Entry(Booking booking, AvailabilitySlot slot, StaffBooking link) {
        Instant confirmedAt() {
            return link == null ? null : link.getStaffConfirmedAt();
        }

        boolean isUpcoming(Instant now) {
            BookingStatus status = booking.getStatus();
            return slot.getEndsAt().isAfter(now)
                    && (status == BookingStatus.CONFIRMED || status == BookingStatus.PENDING_PAYMENT);
        }

        boolean needsAcceptance(Instant now) {
            return booking.getStatus() == BookingStatus.CONFIRMED && confirmedAt() == null
                    && slot.getEndsAt().isAfter(now);
        }
    }

    private List<Entry> entries(UUID staffId) {
        List<UUID> bookingIds = staffBookingRepository.findBookingIdsForStaff(staffId);
        if (bookingIds.isEmpty()) {
            return List.of();
        }
        List<Booking> bookings = bookingRepository.findAllById(bookingIds);
        Map<UUID, AvailabilitySlot> slots = slotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        Map<UUID, StaffBooking> links = new HashMap<>();
        staffBookingRepository.findByBookingIdIn(bookingIds).forEach(l -> links.put(l.getBookingId(), l));
        List<Entry> result = new ArrayList<>();
        for (Booking booking : bookings) {
            AvailabilitySlot slot = slots.get(booking.getAvailabilitySlotId());
            if (slot != null) {
                result.add(new Entry(booking, slot, links.get(booking.getId())));
            }
        }
        return result;
    }

    private List<Review> reviewsOf(List<Entry> entries) {
        if (entries.isEmpty()) {
            return List.of();
        }
        return reviewRepository.findByBookingIdIn(entries.stream().map(e -> e.booking.getId()).toList());
    }

    private Staff requireOwnStaff(UUID staffId, UUID userId) {
        Staff staff = staffRepository.findById(staffId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Staff not found: " + staffId));
        if (!userId.equals(staff.getUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "This is not your staff profile");
        }
        return staff;
    }

    private Staff requireOwnActiveStaff(UUID staffId, UUID userId) {
        Staff staff = requireOwnStaff(staffId, userId);
        if (!staff.isActive()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Your staff profile is deactivated");
        }
        return staff;
    }

    /** The booking must be one of this staff member's own; anything else is reported as not found. */
    private Booking requireOwnBooking(UUID staffId, UUID bookingId) {
        if (!staffBookingRepository.findBookingIdsForStaff(staffId).contains(bookingId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Appointment not found: " + bookingId);
        }
        return bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Appointment not found: " + bookingId));
    }
}
