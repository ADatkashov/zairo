package com.zairo.factory.workforce;

import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.workforce.WorkerDirectoryDtos.TopWorkerResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.WorkerProfileResponse;
import com.zairo.factory.workforce.WorkerDirectoryDtos.WorkerServiceResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/** The customer-facing side of the workers: who the best ones are, and a worker's public page. */
@Service
public class WorkerDirectoryService {

    /** Reviews a worker needs before they can appear among the best. */
    static final int MIN_REVIEWS_FOR_TOP = 3;

    static final int MAX_TOP = 20;

    private final WorkerCatalog catalog;
    private final ProviderRepository providerRepository;

    public WorkerDirectoryService(WorkerCatalog catalog, ProviderRepository providerRepository) {
        this.catalog = catalog;
        this.providerRepository = providerRepository;
    }

    @Transactional(readOnly = true)
    public List<TopWorkerResponse> top(int limit, String city) {
        return catalog.topRated(MIN_REVIEWS_FOR_TOP, clampLimit(limit), blankToNull(city)).stream()
                .map(TopWorkerResponse::from).toList();
    }

    static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    static int clampLimit(int limit) {
        return Math.max(1, Math.min(limit, MAX_TOP));
    }

    /** 404 for an unknown or deactivated worker, and for one whose business is not ACTIVE (not publicly listed). */
    @Transactional(readOnly = true)
    public WorkerProfileResponse profile(UUID workerId) {
        Worker worker = catalog.find(workerId).filter(Worker::active)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Worker not found: " + workerId));
        Provider provider = providerRepository.findById(worker.providerId())
                .filter(p -> p.getStatus() == ProviderStatus.ACTIVE)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Worker not found: " + workerId));
        WorkerCatalog.Ranked rating = catalog.ratingOf(worker, provider.getName());
        List<WorkerServiceResponse> services = catalog.servicesOf(worker).stream()
                .map(s -> new WorkerServiceResponse(s.id(), s.title(), s.durationMinutes(), s.price(), s.currency()))
                .toList();
        return new WorkerProfileResponse(worker.id(), worker.kind(), provider.getId(), provider.getName(),
                worker.displayName(), worker.photoUrl(),
                rating.reviewCount() == 0 ? null : Math.round(rating.averageRating() * 10) / 10.0,
                rating.reviewCount(), services);
    }
}
