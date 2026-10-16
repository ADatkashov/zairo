package com.zairo.factory.workforce;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.workforce.WorkerDirectoryDtos.FavoriteWorkerResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/** A customer's shortlist of people they like to go to. */
@Service
public class FavoriteWorkerService {

    private final FavoriteWorkerRepository repository;
    private final WorkerCatalog catalog;
    private final ProviderRepository providerRepository;
    private final AvailabilitySlotRepository slotRepository;

    public FavoriteWorkerService(FavoriteWorkerRepository repository, WorkerCatalog catalog,
            ProviderRepository providerRepository, AvailabilitySlotRepository slotRepository) {
        this.repository = repository;
        this.catalog = catalog;
        this.providerRepository = providerRepository;
        this.slotRepository = slotRepository;
    }

    /** Idempotent. 404 for a person who is not publicly listed (unknown, deactivated, business not ACTIVE). */
    @Transactional
    public void add(UUID userId, UUID workerId) {
        if (repository.findByUserIdAndWorkerId(userId, workerId).isPresent()) {
            return;
        }
        if (listed(workerId) == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Worker not found: " + workerId);
        }
        repository.save(new FavoriteWorker(UUID.randomUUID(), userId, workerId, Instant.now()));
    }

    /** Idempotent. */
    @Transactional
    public void remove(UUID userId, UUID workerId) {
        repository.deleteByUserIdAndWorkerId(userId, workerId);
    }

    @Transactional(readOnly = true)
    public boolean isFavorited(UUID userId, UUID workerId) {
        return repository.findByUserIdAndWorkerId(userId, workerId).isPresent();
    }

    /** Newest first; people who have since left, been deactivated or whose business is no longer public are skipped. */
    @Transactional(readOnly = true)
    public List<FavoriteWorkerResponse> list(UUID userId) {
        return repository.findByUserIdOrderByCreatedAtDesc(userId).stream().map(f -> card(f.getWorkerId()))
                .filter(java.util.Objects::nonNull).toList();
    }

    private FavoriteWorkerResponse card(UUID workerId) {
        Worker worker = listed(workerId);
        if (worker == null) {
            return null;
        }
        Provider provider = providerRepository.findById(worker.providerId()).orElseThrow();
        WorkerCatalog.Ranked rating = catalog.ratingOf(worker, provider.getName());
        return new FavoriteWorkerResponse(worker.id(), worker.kind(), provider.getId(), provider.getName(),
                worker.displayName(), worker.photoUrl(),
                rating.reviewCount() == 0 ? null : Math.round(rating.averageRating() * 10) / 10.0,
                rating.reviewCount(), nextFreeAt(worker));
    }

    /** The start of this person's soonest open time, or null when they have none. */
    private Instant nextFreeAt(Worker worker) {
        return slotRepository.findByProviderIdAndEmployeeIdAndStatusAndStartsAtAfter(worker.providerId(),
                worker.id(), AvailabilityStatus.OPEN, Instant.now()).stream().map(AvailabilitySlot::getStartsAt)
                .min(java.util.Comparator.naturalOrder()).orElse(null);
    }

    /** The worker when they are publicly listed, else null. */
    private Worker listed(UUID workerId) {
        return catalog.find(workerId).filter(Worker::active)
                .filter(w -> providerRepository.findById(w.providerId())
                        .filter(p -> p.getStatus() == ProviderStatus.ACTIVE).isPresent())
                .orElse(null);
    }
}
