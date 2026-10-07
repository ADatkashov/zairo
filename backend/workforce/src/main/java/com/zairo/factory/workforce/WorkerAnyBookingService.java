package com.zairo.factory.workforce;

import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.SlotNotAvailableException;
import com.zairo.factory.staff.StaffBookingService;
import com.zairo.factory.vertical.auto.AutoBookingService;
import com.zairo.factory.vertical.beauty.BeautyBookingService;
import com.zairo.factory.vertical.cleaning.CleaningBookingService;
import com.zairo.factory.workforce.WorkerAvailabilityDtos.BookAnyRequest;
import com.zairo.factory.workforce.WorkerAvailabilityDtos.BookAnyResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * "Any master": the customer picks a time, not a person; the system assigns the least busy person who is free then
 * and books through that person's own directory, so every existing rule (service offered, slot claim, payment) is
 * the same as for a named booking. The booking remembers the customer didn't mind who — the business may swap the
 * person later without asking.
 *
 * <p>Deliberately not {@code @Transactional}: each directory's booking call is its own transaction, so when
 * someone else wins a race for the same time and one attempt fails, the next candidate can still be tried.
 */
@Service
public class WorkerAnyBookingService {

    private final WorkerAvailabilityService availabilityService;
    private final WorkerBookingStateRepository stateRepository;
    private final BeautyBookingService beautyBookingService;
    private final AutoBookingService autoBookingService;
    private final CleaningBookingService cleaningBookingService;
    private final StaffBookingService staffBookingService;

    public WorkerAnyBookingService(WorkerAvailabilityService availabilityService,
            WorkerBookingStateRepository stateRepository, BeautyBookingService beautyBookingService,
            AutoBookingService autoBookingService, CleaningBookingService cleaningBookingService,
            StaffBookingService staffBookingService) {
        this.availabilityService = availabilityService;
        this.stateRepository = stateRepository;
        this.beautyBookingService = beautyBookingService;
        this.autoBookingService = autoBookingService;
        this.cleaningBookingService = cleaningBookingService;
        this.staffBookingService = staffBookingService;
    }

    public BookAnyResponse book(UUID providerId, UUID callerId, BookAnyRequest request) {
        if (!callerId.equals(request.userId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot book on behalf of a different user");
        }
        List<WorkerAvailabilityService.Candidate> candidates = availabilityService.candidatesAt(providerId,
                request.serviceId(), request.startsAt());
        if (candidates.isEmpty()) {
            throw new SlotNotAvailableException("That time is no longer available");
        }
        for (WorkerAvailabilityService.Candidate candidate : candidates) {
            Worker worker = candidate.worker();
            if (worker.kind() == WorkerKind.MECHANIC && request.vehicleId() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "vehicleId is required for this business");
            }
            Booking booking;
            try {
                booking = WorkerAssignmentContext.runAssigning(() -> bookWith(worker, candidate, request));
            } catch (SlotNotAvailableException lostRace) {
                continue; // someone took that person/time a moment ago — try the next person
            }
            stateRepository.save(new WorkerBookingState(booking.getId(), worker.id(),
                    WorkerBookingState.Preference.ANY, Instant.now()));
            return new BookAnyResponse(booking.getId(), worker.id(), worker.kind(), booking.getUserId(),
                    booking.getServiceId(), booking.getAvailabilitySlotId(), booking.getStatus().name(),
                    booking.getTotalPrice(), booking.getCurrency(), booking.getCreatedAt());
        }
        throw new SlotNotAvailableException("That time is no longer available");
    }

    private Booking bookWith(Worker worker, WorkerAvailabilityService.Candidate candidate, BookAnyRequest request) {
        UUID slotId = candidate.slot().getId();
        // The price argument is ignored by core booking (the service's own price always wins).
        BigDecimal ignored = BigDecimal.ZERO;
        return switch (worker.kind()) {
            case MASTER -> beautyBookingService.createBooking(request.userId(), worker.id(), request.serviceId(),
                    slotId, ignored).booking();
            case MECHANIC -> autoBookingService.createBooking(request.userId(), worker.id(), request.vehicleId(),
                    request.serviceId(), slotId, ignored).booking();
            case CLEANER -> cleaningBookingService.createBooking(request.userId(), worker.id(), request.serviceId(),
                    slotId, ignored).booking();
            case STAFF -> staffBookingService.createBooking(request.userId(), worker.id(), request.serviceId(), slotId,
                    ignored).booking();
        };
    }
}
