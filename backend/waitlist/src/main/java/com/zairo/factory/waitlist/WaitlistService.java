package com.zairo.factory.waitlist;

import com.zairo.factory.booking.AvailabilitySlotOpenedEvent;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.waitlist.WaitlistDtos.WaitlistEntryResponse;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class WaitlistService {

    private final WaitlistRepository waitlistRepository;
    private final ProviderRepository providerRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    public WaitlistService(WaitlistRepository waitlistRepository, ProviderRepository providerRepository,
            ApplicationEventPublisher eventPublisher, Clock clock) {
        this.waitlistRepository = waitlistRepository;
        this.providerRepository = providerRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    /**
     * Idempotent: joining again only changes the wanted window. A window that is empty or already over is a 400 (it
     * could never match anything).
     */
    @Transactional
    public void join(UUID userId, UUID providerId, Instant from, Instant to) {
        if (to != null && (!to.isAfter(clock.instant()) || (from != null && !to.isAfter(from)))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The wanted time window is empty or in the past");
        }
        providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        WaitlistEntry existing = waitlistRepository.findByUserIdAndProviderId(userId, providerId).orElse(null);
        if (existing != null) {
            existing.changeWindow(from, to);
            waitlistRepository.save(existing);
            return;
        }
        waitlistRepository.save(new WaitlistEntry(UUID.randomUUID(), userId, providerId, from, to, clock.instant()));
    }

    /** Idempotent — leaving a list the user is not on is a no-op. */
    @Transactional
    public void leave(UUID userId, UUID providerId) {
        waitlistRepository.deleteByUserIdAndProviderId(userId, providerId);
    }

    /** The user's active entries (a window that has passed is hidden), newest first. */
    @Transactional(readOnly = true)
    public List<WaitlistEntryResponse> list(UUID userId) {
        Instant now = clock.instant();
        return waitlistRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .filter(entry -> entry.getWindowEnd() == null || entry.getWindowEnd().isAfter(now))
                .map(entry -> new WaitlistEntryResponse(entry.getProviderId(),
                        providerRepository.findById(entry.getProviderId()).map(Provider::getName).orElse(""),
                        entry.getWindowStart(), entry.getWindowEnd(), entry.getCreatedAt()))
                .toList();
    }

    /**
     * A time opened up: tell everyone waiting for it (except whoever just gave it up) and take them off the list.
     * {@code REQUIRES_NEW} because this runs after the cancelling transaction committed.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void slotOpened(AvailabilitySlotOpenedEvent event) {
        for (WaitlistEntry entry : waitlistRepository.findWaitingFor(event.providerId(), event.releasedByUserId(),
                event.startsAt())) {
            waitlistRepository.delete(entry);
            eventPublisher.publishEvent(new WaitlistSlotOpenedEvent(entry.getUserId(), entry.getProviderId(),
                    event.startsAt()));
        }
    }
}
