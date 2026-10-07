package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.booking.BookingStatus;
import java.time.Duration;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Gives an appointment to another person at the same time — the thing that turns "the master is sick" from lost
 * revenue into a handled appointment. Only a colleague of the same kind (a beauty master for a master, ...) who
 * performs the service can take it, and never someone already booked or off at that time (in this business or any
 * other: the same human is one person).
 *
 * <p>Two strictness levels. The system picking a replacement on its own (customer said "any master") only uses a
 * person who actually works at that time. The owner choosing by hand may also pick someone outside their usual
 * hours — the owner knows, the system doesn't — in which case a slot is created for that moment.
 */
@Service
public class WorkerReassignmentService {

    /** A person who could take the appointment; {@code atWorkingTime} = it falls within their usual hours. */
    public record Replacement(Worker worker, boolean atWorkingTime) {
    }

    private final WorkerCatalog catalog;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository slotRepository;
    private final WorkerBookingStateRepository stateRepository;
    private final WorkerChangeRequestRepository requestRepository;
    private final WorkerTimeOffRepository timeOffRepository;
    private final WorkerScheduleRepository scheduleRepository;
    private final WorkerBookings workerBookings;
    private final BookingService bookingService;
    private final WorkerSlotGenerator generator;
    private final PersonLock personLock;
    private final ApplicationEventPublisher eventPublisher;
    private final WorkerPricingService pricingService;

    public WorkerReassignmentService(WorkerCatalog catalog, BookingRepository bookingRepository,
            AvailabilitySlotRepository slotRepository, WorkerBookingStateRepository stateRepository,
            WorkerChangeRequestRepository requestRepository, WorkerTimeOffRepository timeOffRepository,
            WorkerScheduleRepository scheduleRepository, WorkerBookings workerBookings,
            BookingService bookingService, WorkerSlotGenerator generator, PersonLock personLock,
            ApplicationEventPublisher eventPublisher, WorkerPricingService pricingService) {
        this.pricingService = pricingService;
        this.catalog = catalog;
        this.bookingRepository = bookingRepository;
        this.slotRepository = slotRepository;
        this.stateRepository = stateRepository;
        this.requestRepository = requestRepository;
        this.timeOffRepository = timeOffRepository;
        this.scheduleRepository = scheduleRepository;
        this.workerBookings = workerBookings;
        this.bookingService = bookingService;
        this.generator = generator;
        this.personLock = personLock;
        this.eventPublisher = eventPublisher;
    }

    /** Who could take this appointment, those working at that time first. */
    @Transactional(readOnly = true)
    public List<Replacement> replacements(UUID bookingId) {
        Booking booking = activeBooking(bookingId);
        AvailabilitySlot slot = slotOf(booking);
        Worker current = catalog.workerOfBooking(bookingId).orElse(null);
        if (current == null) {
            return List.of();
        }
        return replacementsFor(booking, slot, current);
    }

    private List<Replacement> replacementsFor(Booking booking, AvailabilitySlot slot, Worker current) {
        List<Replacement> result = new ArrayList<>();
        for (Worker candidate : catalog.findOfferingService(slot.getProviderId(), booking.getServiceId())) {
            if (candidate.kind() != current.kind() || candidate.id().equals(current.id()) || samePerson(candidate, current)) {
                continue;
            }
            if (!isFree(candidate, slot)) {
                continue;
            }
            result.add(new Replacement(candidate, atWorkingTime(candidate, booking, slot)));
        }
        result.sort(Comparator.comparing((Replacement r) -> !r.atWorkingTime())
                .thenComparing(r -> r.worker().displayName(), String.CASE_INSENSITIVE_ORDER));
        return result;
    }

    /**
     * Gives the appointment to {@code toWorkerId}. {@code allowOffHours}: the owner's manual choice may be outside
     * the person's usual hours. Resolves an open "ask the customer" request with {@code resolution}.
     */
    @Transactional
    public Booking reassign(UUID bookingId, UUID toWorkerId, boolean allowOffHours,
            WorkerChangeRequest.Resolution resolution, boolean customerDidntMind) {
        Booking booking = activeBooking(bookingId);
        AvailabilitySlot slot = slotOf(booking);
        Worker current = catalog.workerOfBooking(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT,
                        "This appointment has no person to replace"));
        Worker target = catalog.find(toWorkerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + toWorkerId));
        if (!target.active() || !target.providerId().equals(slot.getProviderId())
                || target.kind() != current.kind() || target.id().equals(current.id())
                || samePerson(target, current) || !catalog.offersService(target, booking.getServiceId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "That person can't take this appointment");
        }
        personLock.acquire(target);
        if (!isFree(target, slot)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "That person is not free at that time");
        }

        AvailabilitySlot targetSlot = ownOpenSlotAt(target, slot);
        if (targetSlot == null) {
            boolean sharedSlotStays = slot.getEmployeeId() == null && !scheduleRepository.existsById(target.id())
                    && catalog.hasLink(current.kind(), bookingId);
            if (sharedSlotStays) {
                targetSlot = slot;
            } else if (allowOffHours) {
                targetSlot = slotRepository.save(new AvailabilitySlot(UUID.randomUUID(), slot.getProviderId(),
                        slot.getStartsAt(), slot.getEndsAt(), AvailabilityStatus.OPEN, target.id()));
            } else {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "That person doesn't work at that time");
            }
        }
        if (!targetSlot.getId().equals(slot.getId())) {
            bookingService.moveToSlotAuthorized(bookingId, targetSlot.getId());
        }
        catalog.relink(target, bookingId);

        // The customer never pays more than they agreed to: a pricier replacement is absorbed by the business (the
        // booking keeps its price), a cheaper one lowers it — and payments returns what was already paid above it.
        BigDecimal reducedTo = null;
        BigDecimal replacementPrice = pricingService
                .effectivePrice(slot.getProviderId(), target.id(), booking.getServiceId()).orElse(null);
        if (replacementPrice != null && replacementPrice.compareTo(booking.getTotalPrice()) < 0) {
            bookingService.reducePriceAuthorized(bookingId, replacementPrice);
            reducedTo = replacementPrice;
        }

        WorkerBookingState state = stateRepository.findById(bookingId).orElse(null);
        if (state == null) {
            state = new WorkerBookingState(bookingId, target.id(), WorkerBookingState.Preference.SPECIFIC,
                    Instant.now());
        } else {
            state.reassignTo(target.id());
        }
        stateRepository.save(state);
        requestRepository.findById(bookingId).ifPresent(r -> {
            r.resolve(resolution, Instant.now());
            requestRepository.save(r);
        });
        // The slot the previous person held may belong in their calendar (or not, if they're off) — let the
        // generator decide.
        if (scheduleRepository.existsById(current.id())) {
            generator.regenerate(current.id());
        }
        eventPublisher.publishEvent(new WorkerReassignedEvent(bookingId, booking.getUserId(), slot.getProviderId(),
                current.displayName(), target.displayName(), customerDidntMind, reducedTo));
        return bookingRepository.findById(bookingId).orElse(booking);
    }

    /**
     * The system re-assigns an appointment on its own — only for customers who said "any master" — to the least
     * busy replacement who works at that time. Own transaction, so one failure never affects the caller or other
     * appointments.
     *
     * @return whether it found someone and did it
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean tryAutoReassign(UUID bookingId) {
        Booking booking = activeBooking(bookingId);
        AvailabilitySlot slot = slotOf(booking);
        Worker current = catalog.workerOfBooking(bookingId).orElse(null);
        if (current == null) {
            return false;
        }
        Instant now = Instant.now();
        Map<UUID, Integer> load = new HashMap<>();
        List<Replacement> options = replacementsFor(booking, slot, current).stream()
                .filter(Replacement::atWorkingTime).toList();
        if (options.isEmpty()) {
            return false;
        }
        for (Replacement option : options) {
            load.put(option.worker().id(),
                    workerBookings.activeOverlapping(option.worker(), now, now.plus(Duration.ofDays(30))).size());
        }
        Replacement best = options.stream().min(Comparator.comparingInt(o -> load.get(o.worker().id()))).orElseThrow();
        reassign(bookingId, best.worker().id(), false, WorkerChangeRequest.Resolution.OWNER_DECIDED, true);
        return true;
    }

    // --- internals ---

    private Booking activeBooking(UUID bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        if (booking.getStatus() != BookingStatus.CONFIRMED && booking.getStatus() != BookingStatus.PENDING_PAYMENT) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This appointment is no longer active");
        }
        return booking;
    }

    private AvailabilitySlot slotOf(Booking booking) {
        return slotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Slot not found"));
    }

    private static boolean samePerson(Worker a, Worker b) {
        return a.userId() != null && a.userId().equals(b.userId());
    }

    /** Not off, and not already booked at that time anywhere (the same human counts once). */
    private boolean isFree(Worker worker, AvailabilitySlot slot) {
        Instant from = slot.getStartsAt();
        Instant to = slot.getEndsAt();
        if (timeOffRepository.findByWorkerIdAndEndsAtAfterOrderByStartsAt(worker.id(), from).stream()
                .anyMatch(t -> t.overlaps(from, to))) {
            return false;
        }
        List<Worker> samePerson = worker.userId() == null ? List.of(worker) : catalog.findByUserId(worker.userId());
        for (Worker w : samePerson) {
            if (!workerBookings.activeOverlapping(w, from, to).isEmpty()) {
                return false;
            }
        }
        return true;
    }

    private boolean atWorkingTime(Worker worker, Booking booking, AvailabilitySlot slot) {
        if (ownOpenSlotAt(worker, slot) != null) {
            return true;
        }
        Optional<Worker> current = catalog.workerOfBooking(booking.getId());
        return slot.getEmployeeId() == null && !scheduleRepository.existsById(worker.id())
                && current.isPresent() && catalog.hasLink(current.get().kind(), booking.getId());
    }

    /** The person's own open slot covering exactly the appointment's time, if they have one. */
    private AvailabilitySlot ownOpenSlotAt(Worker worker, AvailabilitySlot slot) {
        return slotRepository.findByProviderIdAndEmployeeIdAndStatusAndStartsAtAfter(worker.providerId(), worker.id(),
                AvailabilityStatus.OPEN, slot.getStartsAt().minusSeconds(1)).stream()
                .filter(s -> s.getStartsAt().equals(slot.getStartsAt()) && s.getEndsAt().equals(slot.getEndsAt()))
                .findFirst().orElse(null);
    }
}
