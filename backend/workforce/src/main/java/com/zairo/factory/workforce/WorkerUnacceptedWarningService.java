package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The early signal: "Accept" is the worker's way of saying "I'll be there", so an appointment still not accepted
 * shortly before the visit warns the owner while there is time to hand it to someone else.
 */
@Service
public class WorkerUnacceptedWarningService {

    /** How long before the visit a still-unaccepted appointment counts as a warning. */
    public static final Duration WINDOW = Duration.ofHours(12);

    private final AvailabilitySlotRepository slotRepository;
    private final BookingRepository bookingRepository;
    private final WorkerCatalog catalog;
    private final WorkerBookingStateRepository stateRepository;
    private final ApplicationEventPublisher eventPublisher;

    public WorkerUnacceptedWarningService(AvailabilitySlotRepository slotRepository,
            BookingRepository bookingRepository, WorkerCatalog catalog,
            WorkerBookingStateRepository stateRepository, ApplicationEventPublisher eventPublisher) {
        this.slotRepository = slotRepository;
        this.bookingRepository = bookingRepository;
        this.catalog = catalog;
        this.stateRepository = stateRepository;
        this.eventPublisher = eventPublisher;
    }

    /** Whether this appointment is one the worker should have accepted by now (used by the owner's list too). */
    static boolean isUnaccepted(Worker worker, Booking booking, AvailabilitySlot slot, WorkerBookingState state,
            Instant now) {
        return booking.getStatus() == BookingStatus.CONFIRMED
                // Without an account the person has no way to accept, so silence means nothing.
                && worker.userId() != null
                && slot.getStartsAt().isAfter(now)
                && slot.getStartsAt().isBefore(now.plus(WINDOW))
                && (state == null || (state.getConfirmedAt() == null && state.getDeclinedAt() == null));
    }

    /** Warns the owner once per appointment. @return how many warnings were raised. */
    @Transactional
    public int warnDue(Instant now) {
        List<AvailabilitySlot> slots = slotRepository.findByStatusAndStartsAtBetween(AvailabilityStatus.BOOKED, now,
                now.plus(WINDOW));
        if (slots.isEmpty()) {
            return 0;
        }
        Map<UUID, AvailabilitySlot> bySlot = slots.stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, Function.identity()));
        int warned = 0;
        for (Booking booking : bookingRepository.findByAvailabilitySlotIdIn(List.copyOf(bySlot.keySet()))) {
            Worker worker = catalog.workerOfBooking(booking.getId()).orElse(null);
            if (worker == null) {
                continue;
            }
            WorkerBookingState state = stateRepository.findById(booking.getId()).orElse(null);
            AvailabilitySlot slot = bySlot.get(booking.getAvailabilitySlotId());
            if (!isUnaccepted(worker, booking, slot, state, now)
                    || (state != null && state.getUnacceptedWarnedAt() != null)) {
                continue;
            }
            if (state == null) {
                state = new WorkerBookingState(booking.getId(), worker.id(), WorkerBookingState.Preference.SPECIFIC,
                        now);
            }
            state.markUnacceptedWarned(now);
            stateRepository.save(state);
            eventPublisher.publishEvent(new WorkerNotAcceptedEvent(booking.getId(), worker.providerId(),
                    worker.displayName(), slot.getStartsAt()));
            warned++;
        }
        return warned;
    }
}
