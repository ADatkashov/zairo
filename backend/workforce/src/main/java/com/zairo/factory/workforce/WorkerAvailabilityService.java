package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotDtos.AvailabilitySlotResponse;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.workforce.WorkerAvailabilityDtos.AnySlotResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * The times a customer may actually book: for one chosen person, or merged across everyone who does the service
 * ("any master"). A time is offered only if the person works then, isn't on time off, and isn't already booked
 * anywhere — so the customer never picks a master who isn't there.
 */
@Service
public class WorkerAvailabilityService {

    /** A time with the person who would serve it. */
    record Candidate(Worker worker, AvailabilitySlot slot) {
    }

    private static final Duration LOOKAHEAD = Duration.ofDays(60);

    private final WorkerCatalog catalog;
    private final WorkerScheduleRepository scheduleRepository;
    private final WorkerTimeOffRepository timeOffRepository;
    private final AvailabilitySlotRepository slotRepository;
    private final WorkerBookings workerBookings;
    private final WorkforceSettingsService settingsService;

    public WorkerAvailabilityService(WorkerCatalog catalog, WorkerScheduleRepository scheduleRepository,
            WorkerTimeOffRepository timeOffRepository, AvailabilitySlotRepository slotRepository,
            WorkerBookings workerBookings, WorkforceSettingsService settingsService) {
        this.catalog = catalog;
        this.scheduleRepository = scheduleRepository;
        this.timeOffRepository = timeOffRepository;
        this.slotRepository = slotRepository;
        this.workerBookings = workerBookings;
        this.settingsService = settingsService;
    }

    /** The bookable times of one person. Empty when the business doesn't let customers choose a person. */
    @Transactional(readOnly = true)
    public List<AvailabilitySlotResponse> forWorker(UUID providerId, UUID workerId) {
        Worker worker = catalog.find(workerId).filter(w -> w.providerId().equals(providerId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Not found: " + workerId));
        if (!worker.active() || !settingsService.allowsWorkerChoice(providerId)) {
            return List.of();
        }
        return bookableSlots(worker, Instant.now()).stream()
                .map(s -> new AvailabilitySlotResponse(s.getId(), s.getProviderId(), s.getStartsAt(), s.getEndsAt(),
                        s.getStatus(), s.getEmployeeId()))
                .toList();
    }

    /** Merged times of everyone who does the service; each time carries the person the system would assign. */
    @Transactional(readOnly = true)
    public List<AnySlotResponse> forAny(UUID providerId, UUID serviceId) {
        Map<String, List<Candidate>> byTime = candidatesByTime(providerId, serviceId);
        List<AnySlotResponse> result = new ArrayList<>();
        for (List<Candidate> group : byTime.values()) {
            Candidate best = group.get(0);
            result.add(new AnySlotResponse(best.slot().getId(), best.slot().getStartsAt(), best.slot().getEndsAt(),
                    best.worker().id(), best.worker().kind()));
        }
        result.sort(Comparator.comparing(AnySlotResponse::startsAt));
        return result;
    }

    /** Everyone who could serve a booking starting exactly at {@code startsAt}, the least busy first. */
    List<Candidate> candidatesAt(UUID providerId, UUID serviceId, Instant startsAt) {
        for (List<Candidate> group : candidatesByTime(providerId, serviceId).values()) {
            if (group.get(0).slot().getStartsAt().equals(startsAt)) {
                return group;
            }
        }
        return List.of();
    }

    /** Candidates grouped by (start, end), each group ordered least-busy person first. */
    private Map<String, List<Candidate>> candidatesByTime(UUID providerId, UUID serviceId) {
        Instant now = Instant.now();
        Map<String, List<Candidate>> byTime = new LinkedHashMap<>();
        Map<UUID, Integer> load = new java.util.HashMap<>();
        for (Worker worker : catalog.findOfferingService(providerId, serviceId)) {
            load.put(worker.id(), workerBookings.activeOverlapping(worker, now, now.plus(Duration.ofDays(30))).size());
            for (AvailabilitySlot slot : bookableSlots(worker, now)) {
                byTime.computeIfAbsent(slot.getStartsAt().toEpochMilli() + "-" + slot.getEndsAt().toEpochMilli(),
                        k -> new ArrayList<>()).add(new Candidate(worker, slot));
            }
        }
        Comparator<Candidate> leastBusy = Comparator.<Candidate>comparingInt(c -> load.getOrDefault(c.worker().id(), 0))
                .thenComparing(c -> c.worker().displayName(), String.CASE_INSENSITIVE_ORDER);
        byTime.values().forEach(group -> group.sort(leastBusy));
        return byTime;
    }

    /** Open future slots of a person, minus time off and anything overlapping their bookings anywhere. */
    List<AvailabilitySlot> bookableSlots(Worker worker, Instant now) {
        List<AvailabilitySlot> slots = scheduleRepository.existsById(worker.id())
                ? slotRepository.findByProviderIdAndEmployeeIdAndStatusAndStartsAtAfter(worker.providerId(),
                        worker.id(), AvailabilityStatus.OPEN, now)
                : slotRepository.findByProviderIdAndEmployeeIdIsNullAndStatusAndStartsAtAfter(worker.providerId(),
                        AvailabilityStatus.OPEN, now);
        if (slots.isEmpty()) {
            return List.of();
        }
        Instant horizon = now.plus(LOOKAHEAD);
        List<WorkerTimeOff> off = timeOffRepository.findByWorkerIdAndEndsAtAfterOrderByStartsAt(worker.id(), now);
        List<Worker> samePerson = worker.userId() == null ? List.of(worker) : catalog.findByUserId(worker.userId());
        List<WorkerBookings.ActiveBooking> busy = new ArrayList<>();
        for (Worker w : samePerson) {
            busy.addAll(workerBookings.activeOverlapping(w, now, horizon));
        }
        return slots.stream()
                .filter(s -> off.stream().noneMatch(t -> t.overlaps(s.getStartsAt(), s.getEndsAt())))
                .filter(s -> busy.stream().noneMatch(b -> b.slot().getStartsAt().isBefore(s.getEndsAt())
                        && b.slot().getEndsAt().isAfter(s.getStartsAt())))
                .sorted(Comparator.comparing(AvailabilitySlot::getStartsAt))
                .toList();
    }
}
