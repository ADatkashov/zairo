package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingService;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.workforce.WorkerChangeDtos.ChangeRequestResponse;
import com.zairo.factory.workforce.WorkerChangeDtos.ChangeResponseRequest;
import com.zairo.factory.workforce.WorkerChangeDtos.ReplacementOption;
import com.zairo.factory.workforce.WorkerChangeDtos.TimeOption;
import java.time.Instant;
import java.util.ArrayList;
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
 * The customer's side of "your person can't make it": they see what the owner asked them and choose a colleague at
 * the same time, another time with the same person, or to cancel with a refund. Every choice is checked against
 * what is actually still possible right now, never against what the app showed earlier.
 */
@Service
public class WorkerChangeService {

    private static final int MAX_OTHER_TIMES = 4;

    private final WorkerCatalog catalog;
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository slotRepository;
    private final WorkerBookingStateRepository stateRepository;
    private final WorkerChangeRequestRepository requestRepository;
    private final WorkerTimeOffRepository timeOffRepository;
    private final WorkerReassignmentService reassignmentService;
    private final WorkerAvailabilityService availabilityService;
    private final BookingService bookingService;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceRepository;

    public WorkerChangeService(WorkerCatalog catalog, BookingRepository bookingRepository,
            AvailabilitySlotRepository slotRepository, WorkerBookingStateRepository stateRepository,
            WorkerChangeRequestRepository requestRepository, WorkerTimeOffRepository timeOffRepository,
            WorkerReassignmentService reassignmentService, WorkerAvailabilityService availabilityService,
            BookingService bookingService, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceRepository) {
        this.catalog = catalog;
        this.bookingRepository = bookingRepository;
        this.slotRepository = slotRepository;
        this.stateRepository = stateRepository;
        this.requestRepository = requestRepository;
        this.timeOffRepository = timeOffRepository;
        this.reassignmentService = reassignmentService;
        this.availabilityService = availabilityService;
        this.bookingService = bookingService;
        this.providerRepository = providerRepository;
        this.serviceRepository = serviceRepository;
    }

    @Transactional(readOnly = true)
    public List<ChangeRequestResponse> list(UUID userId) {
        List<Booking> active = bookingRepository.findByUserId(userId).stream()
                .filter(b -> b.getStatus() == BookingStatus.CONFIRMED || b.getStatus() == BookingStatus.PENDING_PAYMENT)
                .toList();
        if (active.isEmpty()) {
            return List.of();
        }
        Map<UUID, WorkerChangeRequest> open = requestRepository
                .findByBookingIdInAndStatus(active.stream().map(Booking::getId).toList(),
                        WorkerChangeRequest.Status.OPEN).stream()
                .collect(Collectors.toMap(WorkerChangeRequest::getBookingId, Function.identity()));
        List<ChangeRequestResponse> result = new ArrayList<>();
        for (Booking booking : active) {
            WorkerChangeRequest request = open.get(booking.getId());
            if (request == null) {
                continue;
            }
            ChangeRequestResponse response = describe(booking, request);
            if (response != null) {
                result.add(response);
            }
        }
        result.sort(java.util.Comparator.comparing(ChangeRequestResponse::startsAt));
        return result;
    }

    @Transactional
    public void respond(UUID userId, UUID bookingId, ChangeResponseRequest request) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + bookingId));
        if (!booking.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "This is not your appointment");
        }
        WorkerChangeRequest changeRequest = requestRepository.findById(bookingId)
                .filter(r -> r.getStatus() == WorkerChangeRequest.Status.OPEN)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT, "Nothing to decide here anymore"));
        ChangeRequestResponse current = describe(booking, changeRequest);
        if (current == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Nothing to decide here anymore");
        }
        switch (request.choice()) {
            case REPLACE -> {
                if (request.workerId() == null || current.replacements().stream()
                        .noneMatch(r -> r.workerId().equals(request.workerId()))) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "That colleague is not available");
                }
                reassignmentService.reassign(bookingId, request.workerId(), false,
                        WorkerChangeRequest.Resolution.REPLACED, false);
            }
            case MOVE -> {
                if (request.slotId() == null
                        || current.otherTimes().stream().noneMatch(t -> t.slotId().equals(request.slotId()))) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "That time is not available");
                }
                bookingService.moveToSlotAuthorized(bookingId, request.slotId());
                resolve(changeRequest, WorkerChangeRequest.Resolution.MOVED);
            }
            case CANCEL -> {
                bookingService.cancelBooking(bookingId, userId, "The person you booked was unavailable");
                resolve(changeRequest, WorkerChangeRequest.Resolution.CANCELLED);
            }
        }
    }

    private void resolve(WorkerChangeRequest request, WorkerChangeRequest.Resolution resolution) {
        request.resolve(resolution, Instant.now());
        requestRepository.save(request);
    }

    /** What the customer can pick right now, or null when the appointment no longer needs a decision. */
    private ChangeRequestResponse describe(Booking booking, WorkerChangeRequest request) {
        AvailabilitySlot slot = slotRepository.findById(booking.getAvailabilitySlotId()).orElse(null);
        Worker worker = catalog.workerOfBooking(booking.getId()).orElse(null);
        if (slot == null || worker == null) {
            return null;
        }
        Instant now = Instant.now();
        String reason = WorkerOwnerService.reasonOf(worker, slot, stateRepository.findById(booking.getId()).orElse(null),
                timeOffRepository.findByWorkerIdAndEndsAtAfterOrderByStartsAt(worker.id(), now));
        if (reason == null) {
            return null;
        }
        List<ReplacementOption> replacements = reassignmentService.replacements(booking.getId()).stream()
                .filter(WorkerReassignmentService.Replacement::atWorkingTime)
                .map(r -> new ReplacementOption(r.worker().id(), r.worker().displayName())).toList();
        List<TimeOption> otherTimes = worker.active()
                ? availabilityService.bookableSlots(worker, now).stream()
                        .filter(s -> !s.getId().equals(slot.getId()))
                        .limit(MAX_OTHER_TIMES)
                        .map(s -> new TimeOption(s.getId(), s.getStartsAt(), s.getEndsAt())).toList()
                : List.of();
        Provider provider = providerRepository.findById(slot.getProviderId()).orElse(null);
        ServiceOffering service = serviceRepository.findById(booking.getServiceId()).orElse(null);
        return new ChangeRequestResponse(booking.getId(), slot.getProviderId(),
                provider == null ? null : provider.getName(), service == null ? null : service.getTitle(),
                slot.getStartsAt(), slot.getEndsAt(), worker.displayName(), reason, request.getCreatedAt(),
                replacements, otherTimes);
    }
}
