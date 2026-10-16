package com.zairo.factory.workforce;

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
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.workforce.WorkerPortalDtos.WorkerAppointmentResponse;
import com.zairo.factory.workforce.WorkerPortalDtos.WorkerMembershipResponse;
import com.zairo.factory.workforce.WorkerPortalDtos.WorkerRatingResponse;
import com.zairo.factory.workforce.WorkerPortalDtos.WorkerReviewResponse;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * A worker's own cabinet. A person can work at several businesses and in several directories (a beauty master at
 * one, generic staff at another); every call is scoped to one of the caller's own worker records, so they see and
 * act on exactly the appointments booked with them — never a colleague's, never the business's whole book.
 *
 * <p>The worker may accept, complete or mark a no-show, and may say "I can't attend" — but cancelling (which
 * refunds the customer and frees the slot) is the owner's decision, never the worker's.
 */
@Service
public class WorkerPortalService {

    public enum Scope {
        ALL, UPCOMING, HISTORY
    }

    private static final int MAX_REVIEWS = 100;

    private final WorkerCatalog catalog;
    private final WorkerBookingStateRepository stateRepository;
    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final AvailabilitySlotRepository slotRepository;
    private final ServiceOfferingRepository serviceRepository;
    private final ProviderRepository providerRepository;
    private final UserRepository userRepository;
    private final ReviewRepository reviewRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final WorkerDeclineRecorder declineRecorder;
    private final WorkerAbsenceService absenceService;

    public WorkerPortalService(WorkerCatalog catalog, WorkerBookingStateRepository stateRepository,
            BookingRepository bookingRepository, BookingService bookingService,
            AvailabilitySlotRepository slotRepository, ServiceOfferingRepository serviceRepository,
            ProviderRepository providerRepository, UserRepository userRepository,
            ReviewRepository reviewRepository, ApplicationEventPublisher eventPublisher,
            WorkerDeclineRecorder declineRecorder, WorkerAbsenceService absenceService) {
        this.catalog = catalog;
        this.stateRepository = stateRepository;
        this.bookingRepository = bookingRepository;
        this.bookingService = bookingService;
        this.slotRepository = slotRepository;
        this.serviceRepository = serviceRepository;
        this.providerRepository = providerRepository;
        this.userRepository = userRepository;
        this.reviewRepository = reviewRepository;
        this.eventPublisher = eventPublisher;
        this.declineRecorder = declineRecorder;
        this.absenceService = absenceService;
    }

    @Transactional(readOnly = true)
    public List<WorkerMembershipResponse> memberships(UUID userId) {
        Instant now = Instant.now();
        List<WorkerMembershipResponse> result = new ArrayList<>();
        for (Worker worker : catalog.findByUserId(userId)) {
            Provider provider = providerRepository.findById(worker.providerId()).orElse(null);
            if (provider == null) {
                continue;
            }
            List<Entry> entries = entries(worker);
            int pending = (int) entries.stream().filter(e -> e.needsAcceptance(now)).count();
            List<Review> reviews = reviewsOf(entries);
            Double average = reviews.isEmpty() ? null
                    : reviews.stream().mapToInt(Review::getRatingForWorker).average().orElse(0);
            result.add(new WorkerMembershipResponse(worker.id(), worker.kind(), provider.getId(), provider.getName(),
                    worker.displayName(), worker.photoUrl(), worker.active(), pending, average, reviews.size()));
        }
        result.sort(Comparator.comparing(WorkerMembershipResponse::providerName, String.CASE_INSENSITIVE_ORDER));
        return result;
    }

    @Transactional(readOnly = true)
    public List<WorkerAppointmentResponse> appointments(UUID userId, UUID workerId, Scope scope) {
        Worker worker = requireOwnWorker(workerId, userId);
        Instant now = Instant.now();
        List<Entry> entries = entries(worker).stream()
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
            return new WorkerAppointmentResponse(e.booking.getId(), status.name(), e.slot.getStartsAt(),
                    e.slot.getEndsAt(), e.booking.getServiceId(), service == null ? null : service.getTitle(),
                    customer == null ? null : customer.getDisplayName(),
                    customer == null ? null : customer.getPhone(),
                    e.booking.getTotalPrice(), e.booking.getCurrency(), e.booking.getPaidAmount(),
                    e.booking.getCancellationReason(), e.confirmedAt(), e.declinedAt(),
                    confirmed && e.confirmedAt() == null && e.declinedAt() == null,
                    (confirmed || status == BookingStatus.PENDING_PAYMENT) && e.declinedAt() == null, confirmed,
                    confirmed);
        }).toList();
    }

    /** The worker accepts an appointment: purely an acknowledgement, the booking's status is unchanged. */
    @Transactional
    public void accept(UUID userId, UUID workerId, UUID bookingId) {
        Worker worker = requireOwnActiveWorker(workerId, userId);
        Booking booking = requireOwnBooking(worker, bookingId);
        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Only a confirmed appointment can be accepted (status=" + booking.getStatus() + ")");
        }
        WorkerBookingState state = stateOf(bookingId, worker);
        if (state.getDeclinedAt() != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "You already told the owner you can't attend");
        }
        state.confirm(Instant.now());
        stateRepository.save(state);
    }

    /**
     * "I can't attend": a request to the owner. Deliberately NOT a cancellation — cancelling refunds the customer
     * and frees the slot, and that decision (reassign to a colleague, move, or cancel) is the owner's, since the
     * business, not the worker, carries the lost revenue. The booking is untouched; the owner is told.
     */
    public void cannotAttend(UUID userId, UUID workerId, UUID bookingId, String reason) {
        Worker worker = requireOwnActiveWorker(workerId, userId);
        Booking booking = requireOwnBooking(worker, bookingId);
        if (booking.getStatus() != BookingStatus.CONFIRMED && booking.getStatus() != BookingStatus.PENDING_PAYMENT) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Only an upcoming appointment can be declined (status=" + booking.getStatus() + ")");
        }
        WorkerDeclineRecorder.Recorded recorded = declineRecorder.record(bookingId, worker,
                reason == null || reason.isBlank() ? null : reason.trim());
        if (!recorded.first()) {
            return;
        }
        // A customer who didn't mind who serves them is handed to a free colleague on the spot; the owner only hears
        // about it when that wasn't possible (or the customer chose this person).
        if (recorded.customerDidntMind() && absenceService.autoReassignIfAny(bookingId)) {
            return;
        }
        eventPublisher.publishEvent(new WorkerCannotAttendEvent(bookingId, worker.providerId(), worker.id()));
    }

    @Transactional
    public void complete(UUID userId, UUID workerId, UUID bookingId) {
        Worker worker = requireOwnActiveWorker(workerId, userId);
        requireOwnBooking(worker, bookingId);
        bookingService.completeBookingAuthorized(bookingId);
    }

    @Transactional
    public void markNoShow(UUID userId, UUID workerId, UUID bookingId) {
        Worker worker = requireOwnActiveWorker(workerId, userId);
        requireOwnBooking(worker, bookingId);
        bookingService.markNoShowAuthorized(bookingId);
    }

    @Transactional(readOnly = true)
    public WorkerRatingResponse rating(UUID userId, UUID workerId) {
        return ratingOf(requireOwnWorker(workerId, userId));
    }

    /** The rating of one worker: average, star distribution and the newest reviews with the reviewer's name. */
    @Transactional(readOnly = true)
    public WorkerRatingResponse ratingOf(Worker worker) {
        List<Entry> entries = entries(worker);
        List<Review> reviews = reviewsOf(entries);
        long[] counts = new long[5];
        for (Review review : reviews) {
            if (review.getRatingForWorker() >= 1 && review.getRatingForWorker() <= 5) {
                counts[review.getRatingForWorker() - 1]++;
            }
        }
        Double average = reviews.isEmpty() ? null : reviews.stream().mapToInt(Review::getRatingForWorker).average().orElse(0);

        Map<UUID, Booking> bookingsById = entries.stream()
                .collect(Collectors.toMap(e -> e.booking.getId(), e -> e.booking));
        List<Review> latest = reviews.stream()
                .sorted(Comparator.comparing(Review::getCreatedAt).reversed()).limit(MAX_REVIEWS).toList();
        Map<UUID, User> customers = userRepository.findAllById(latest.stream()
                .map(r -> bookingsById.get(r.getBookingId()).getUserId()).distinct().toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        List<WorkerReviewResponse> rows = latest.stream().map(r -> {
            User customer = customers.get(bookingsById.get(r.getBookingId()).getUserId());
            return new WorkerReviewResponse(r.getId(), r.getBookingId(),
                    customer == null ? null : customer.getDisplayName(), r.getRatingForWorker(), r.getComment(),
                    r.getCreatedAt(), r.getBusinessReply(), r.getBusinessReplyAt());
        }).toList();
        return new WorkerRatingResponse(average, reviews.size(), Arrays.stream(counts).boxed().toList(), rows);
    }

    // --- internals ---

    /** A booking of this worker together with its slot and (if any) the worker's accept/decline state. */
    private record Entry(Booking booking, AvailabilitySlot slot, WorkerBookingState state) {
        Instant confirmedAt() {
            return state == null ? null : state.getConfirmedAt();
        }

        Instant declinedAt() {
            return state == null ? null : state.getDeclinedAt();
        }

        boolean isUpcoming(Instant now) {
            BookingStatus status = booking.getStatus();
            return slot.getEndsAt().isAfter(now)
                    && (status == BookingStatus.CONFIRMED || status == BookingStatus.PENDING_PAYMENT);
        }

        boolean needsAcceptance(Instant now) {
            return booking.getStatus() == BookingStatus.CONFIRMED && confirmedAt() == null && declinedAt() == null
                    && slot.getEndsAt().isAfter(now);
        }
    }

    private List<Entry> entries(Worker worker) {
        List<UUID> bookingIds = List.copyOf(catalog.bookingIdsOf(worker));
        if (bookingIds.isEmpty()) {
            return List.of();
        }
        List<Booking> bookings = bookingRepository.findAllById(bookingIds);
        Map<UUID, AvailabilitySlot> slots = slotRepository
                .findAllById(bookings.stream().map(Booking::getAvailabilitySlotId).distinct().toList()).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        Map<UUID, WorkerBookingState> states = stateRepository.findAllById(bookingIds).stream()
                .collect(Collectors.toMap(WorkerBookingState::getBookingId, Function.identity()));
        List<Entry> result = new ArrayList<>();
        for (Booking booking : bookings) {
            AvailabilitySlot slot = slots.get(booking.getAvailabilitySlotId());
            if (slot != null) {
                result.add(new Entry(booking, slot, states.get(booking.getId())));
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

    private WorkerBookingState stateOf(UUID bookingId, Worker worker) {
        return stateRepository.findById(bookingId).orElseGet(
                () -> new WorkerBookingState(bookingId, worker.id(), WorkerBookingState.Preference.SPECIFIC,
                        Instant.now()));
    }

    private Worker requireOwnWorker(UUID workerId, UUID userId) {
        Worker worker = catalog.find(workerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + workerId));
        if (!userId.equals(worker.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "This is not your profile");
        }
        return worker;
    }

    private Worker requireOwnActiveWorker(UUID workerId, UUID userId) {
        Worker worker = requireOwnWorker(workerId, userId);
        if (!worker.active()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Your profile is deactivated");
        }
        return worker;
    }

    /** The booking must be one of this worker's own; anything else is reported as not found. */
    private Booking requireOwnBooking(Worker worker, UUID bookingId) {
        if (!catalog.bookingIdsOf(worker).contains(bookingId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Appointment not found: " + bookingId);
        }
        return bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Appointment not found: " + bookingId));
    }
}
