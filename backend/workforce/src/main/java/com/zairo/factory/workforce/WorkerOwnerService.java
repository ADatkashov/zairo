package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.workforce.WorkerOwnerDtos.NeedsAttentionResponse;
import com.zairo.factory.workforce.WorkerOwnerDtos.ReplacementResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
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
 * The business owner's side of worker-related appointments: the "needs a decision" list and what to do about each
 * item — hand it to a colleague, ask the customer, or cancel with a refund. The owner (never the worker) is the only
 * one who may cancel with a refund.
 */
@Service
public class WorkerOwnerService {

    static final String CANNOT_ATTEND = "WORKER_CANNOT_ATTEND";
    static final String UNAVAILABLE = "WORKER_UNAVAILABLE";
    static final String INACTIVE = "WORKER_INACTIVE";

    private static final Duration HORIZON = Duration.ofDays(120);

    private final ProviderOwnership providerOwnership;
    private final WorkerCatalog catalog;
    private final WorkerBookingStateRepository stateRepository;
    private final WorkerChangeRequestRepository requestRepository;
    private final WorkerTimeOffRepository timeOffRepository;
    private final WorkerBookings workerBookings;
    private final WorkerReassignmentService reassignmentService;
    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final AvailabilitySlotRepository slotRepository;
    private final ServiceOfferingRepository serviceRepository;
    private final UserRepository userRepository;
    private final ApplicationEventPublisher eventPublisher;

    public WorkerOwnerService(ProviderOwnership providerOwnership, WorkerCatalog catalog,
            WorkerBookingStateRepository stateRepository, WorkerChangeRequestRepository requestRepository,
            WorkerTimeOffRepository timeOffRepository, WorkerBookings workerBookings,
            WorkerReassignmentService reassignmentService, BookingRepository bookingRepository,
            BookingService bookingService, AvailabilitySlotRepository slotRepository,
            ServiceOfferingRepository serviceRepository, UserRepository userRepository,
            ApplicationEventPublisher eventPublisher) {
        this.providerOwnership = providerOwnership;
        this.catalog = catalog;
        this.stateRepository = stateRepository;
        this.requestRepository = requestRepository;
        this.timeOffRepository = timeOffRepository;
        this.workerBookings = workerBookings;
        this.reassignmentService = reassignmentService;
        this.bookingRepository = bookingRepository;
        this.bookingService = bookingService;
        this.slotRepository = slotRepository;
        this.serviceRepository = serviceRepository;
        this.userRepository = userRepository;
        this.eventPublisher = eventPublisher;
    }

    @Transactional(readOnly = true)
    public List<NeedsAttentionResponse> needsAttention(UUID providerId, UUID ownerId) {
        providerOwnership.requireOwner(providerId, ownerId);
        Instant now = Instant.now();
        List<Item> items = new ArrayList<>();
        for (Worker worker : catalog.findByProvider(providerId)) {
            List<WorkerBookings.ActiveBooking> active = workerBookings.activeOverlapping(worker, now,
                    now.plus(HORIZON));
            if (active.isEmpty()) {
                continue;
            }
            List<WorkerTimeOff> timeOff = timeOffRepository
                    .findByWorkerIdAndEndsAtAfterOrderByStartsAt(worker.id(), now);
            Map<UUID, WorkerBookingState> states = stateRepository
                    .findAllById(active.stream().map(a -> a.booking().getId()).toList()).stream()
                    .collect(Collectors.toMap(WorkerBookingState::getBookingId, Function.identity()));
            for (WorkerBookings.ActiveBooking ab : active) {
                WorkerBookingState state = states.get(ab.booking().getId());
                String reason = reasonOf(worker, ab.slot(), state, timeOff);
                if (reason != null) {
                    items.add(new Item(worker, ab, state, reason, timeOff));
                }
            }
        }
        if (items.isEmpty()) {
            return List.of();
        }
        Map<UUID, ServiceOffering> services = serviceRepository
                .findAllById(items.stream().map(i -> i.ab.booking().getServiceId()).distinct().toList()).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, Function.identity()));
        Map<UUID, User> customers = userRepository
                .findAllById(items.stream().map(i -> i.ab.booking().getUserId()).distinct().toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        Map<UUID, WorkerChangeRequest> requests = requestRepository
                .findByBookingIdInAndStatus(items.stream().map(i -> i.ab.booking().getId()).toList(),
                        WorkerChangeRequest.Status.OPEN).stream()
                .collect(Collectors.toMap(WorkerChangeRequest::getBookingId, Function.identity()));

        List<NeedsAttentionResponse> result = new ArrayList<>();
        for (Item item : items) {
            Booking booking = item.ab.booking();
            AvailabilitySlot slot = item.ab.slot();
            ServiceOffering service = services.get(booking.getServiceId());
            User customer = customers.get(booking.getUserId());
            WorkerChangeRequest request = requests.get(booking.getId());
            List<ReplacementResponse> replacements = reassignmentService.replacements(booking.getId()).stream()
                    .map(r -> new ReplacementResponse(r.worker().id(), r.worker().displayName(), r.atWorkingTime()))
                    .toList();
            boolean declined = item.state != null && item.state.getDeclinedAt() != null;
            result.add(new NeedsAttentionResponse(booking.getId(), booking.getStatus().name(), slot.getStartsAt(),
                    slot.getEndsAt(), booking.getServiceId(), service == null ? null : service.getTitle(),
                    customer == null ? null : customer.getDisplayName(),
                    customer == null ? null : customer.getPhone(), booking.getTotalPrice(), booking.getCurrency(),
                    item.worker.id(), item.worker.kind(), item.worker.displayName(), item.reason,
                    declined ? item.state.getDeclineReason() : null,
                    declined ? item.state.getDeclinedAt() : null,
                    item.state != null ? item.state.getPreference().name() : "SPECIFIC",
                    request == null ? null : request.getCreatedAt(), replacements));
        }
        result.sort(Comparator.comparing(NeedsAttentionResponse::startsAt));
        return result;
    }

    /** The owner gives the appointment to a colleague — no customer consent needed, the owner decides. */
    @Transactional
    public void reassign(UUID providerId, UUID bookingId, UUID ownerId, UUID toWorkerId) {
        Booking booking = requireOwnedBooking(providerId, bookingId, ownerId);
        WorkerBookingState state = stateRepository.findById(bookingId).orElse(null);
        boolean didntMind = state != null && state.getPreference() == WorkerBookingState.Preference.ANY;
        reassignmentService.reassign(booking.getId(), toWorkerId, true, WorkerChangeRequest.Resolution.OWNER_DECIDED,
                didntMind);
    }

    /** The owner asks the customer to choose: a colleague at the same time, another time, or cancel with a refund. */
    @Transactional
    public void askCustomer(UUID providerId, UUID bookingId, UUID ownerId) {
        Booking booking = requireOwnedBooking(providerId, bookingId, ownerId);
        Worker worker = catalog.workerOfBooking(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT, "Nobody is assigned"));
        AvailabilitySlot slot = slotRepository.findById(booking.getAvailabilitySlotId()).orElseThrow();
        WorkerBookingState state = stateRepository.findById(bookingId).orElse(null);
        String reason = reasonOf(worker, slot, state,
                timeOffRepository.findByWorkerIdAndEndsAtAfterOrderByStartsAt(worker.id(), Instant.now()));
        if (reason == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Nothing needs a decision for this appointment");
        }
        WorkerChangeRequest existing = requestRepository.findById(bookingId).orElse(null);
        if (existing != null && existing.getStatus() == WorkerChangeRequest.Status.OPEN) {
            return; // already asked — idempotent
        }
        if (existing != null) {
            requestRepository.delete(existing);
            requestRepository.flush();
        }
        requestRepository.save(new WorkerChangeRequest(bookingId, providerId, reason, Instant.now()));
        eventPublisher.publishEvent(new WorkerChangeRequestedEvent(bookingId, booking.getUserId(), providerId,
                worker.displayName()));
    }

    /** Cancel an appointment of this business: slot released, a paid booking refunded, customer notified. */
    @Transactional
    public void cancel(UUID providerId, UUID bookingId, UUID ownerId, String reason) {
        requireOwnedBooking(providerId, bookingId, ownerId);
        bookingService.cancelBookingAuthorized(bookingId, reason == null || reason.isBlank() ? null : reason.trim());
        requestRepository.findById(bookingId).ifPresent(r -> {
            r.resolve(WorkerChangeRequest.Resolution.OWNER_DECIDED, Instant.now());
            requestRepository.save(r);
        });
    }

    /** Why an appointment needs the owner, or null when it doesn't. Shared with the customer-facing side. */
    static String reasonOf(Worker worker, AvailabilitySlot slot, WorkerBookingState state, List<WorkerTimeOff> timeOff) {
        if (state != null && state.getDeclinedAt() != null) {
            return CANNOT_ATTEND;
        }
        if (timeOff.stream().anyMatch(t -> t.overlaps(slot.getStartsAt(), slot.getEndsAt()))) {
            return UNAVAILABLE;
        }
        return worker.active() ? null : INACTIVE;
    }

    private Booking requireOwnedBooking(UUID providerId, UUID bookingId, UUID ownerId) {
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
        return booking;
    }

    private record Item(Worker worker, WorkerBookings.ActiveBooking ab, WorkerBookingState state, String reason,
            List<WorkerTimeOff> timeOff) {
    }
}
