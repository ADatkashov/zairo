package com.zairo.factory.workforce;

import com.zairo.factory.booking.WorkerPriceResolver;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.workforce.WorkerPricingDtos.ServiceWorkerPriceResponse;
import com.zairo.factory.workforce.WorkerPricingDtos.SetWorkerPriceRequest;
import com.zairo.factory.workforce.WorkerPricingDtos.WorkerPriceResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Different prices per worker, entirely under the owner's control: nothing applies unless the business turned the
 * switch on, and the customer is never charged more than the price shown when they booked (the price is copied
 * into the booking).
 */
@Service
public class WorkerPricingService implements WorkerPriceResolver {

    private final WorkerServicePriceRepository repository;
    private final ProviderWorkforceSettingsRepository settingsRepository;
    private final ServiceOfferingRepository serviceRepository;
    private final WorkerScheduleService scheduleService;
    private final ProviderOwnership providerOwnership;

    public WorkerPricingService(WorkerServicePriceRepository repository,
            ProviderWorkforceSettingsRepository settingsRepository, ServiceOfferingRepository serviceRepository,
            WorkerScheduleService scheduleService, ProviderOwnership providerOwnership) {
        this.repository = repository;
        this.settingsRepository = settingsRepository;
        this.serviceRepository = serviceRepository;
        this.scheduleService = scheduleService;
        this.providerOwnership = providerOwnership;
    }

    private boolean enabled(UUID providerId) {
        return settingsRepository.findById(providerId).map(ProviderWorkforceSettings::isWorkerPricingEnabled)
                .orElse(false);
    }

    /** The worker's own price when the business uses per-worker prices and set one that differs from the base. */
    @Override
    @Transactional(readOnly = true)
    public Optional<BigDecimal> priceFor(UUID providerId, UUID workerId, UUID serviceId) {
        if (!enabled(providerId)) {
            return Optional.empty();
        }
        return repository.findByWorkerIdAndServiceId(workerId, serviceId).map(WorkerServicePrice::getPrice);
    }

    /**
     * Whether "any master" may assign this worker: only someone charging the base price, so a customer who
     * didn't choose a person never pays a premium.
     */
    @Transactional(readOnly = true)
    public boolean chargesBasePrice(UUID providerId, UUID workerId, UUID serviceId) {
        Optional<BigDecimal> own = priceFor(providerId, workerId, serviceId);
        if (own.isEmpty()) {
            return true;
        }
        return serviceRepository.findById(serviceId).map(ServiceOffering::getPrice)
                .map(base -> base.compareTo(own.get()) == 0).orElse(true);
    }

    /** Public: prices that differ per worker for a service — only when the business uses them. */
    @Transactional(readOnly = true)
    public List<ServiceWorkerPriceResponse> forService(UUID providerId, UUID serviceId) {
        if (!enabled(providerId)) {
            return List.of();
        }
        return repository.findByProviderIdAndServiceId(providerId, serviceId).stream()
                .map(p -> new ServiceWorkerPriceResponse(p.getWorkerId(), p.getPrice())).toList();
    }

    @Transactional(readOnly = true)
    public List<WorkerPriceResponse> ofWorker(UUID providerId, UUID workerId, UUID ownerId) {
        scheduleService.requireOwnerOfWorker(providerId, workerId, ownerId);
        return repository.findByWorkerId(workerId).stream()
                .map(p -> new WorkerPriceResponse(p.getServiceId(), p.getPrice())).toList();
    }

    @Transactional
    public List<WorkerPriceResponse> set(UUID providerId, UUID workerId, UUID ownerId, SetWorkerPriceRequest request) {
        providerOwnership.requireOwner(providerId, ownerId);
        scheduleService.requireOwnerOfWorker(providerId, workerId, ownerId);
        ServiceOffering service = serviceRepository.findById(request.serviceId())
                .filter(s -> s.getProviderId().equals(providerId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Service not found: " + request.serviceId()));
        Instant now = Instant.now();
        Optional<WorkerServicePrice> existing = repository.findByWorkerIdAndServiceId(workerId, service.getId());
        if (request.price() == null || request.price().compareTo(service.getPrice()) == 0) {
            existing.ifPresent(repository::delete);
        } else if (existing.isPresent()) {
            existing.get().setPrice(request.price(), now);
        } else {
            repository.save(new WorkerServicePrice(providerId, workerId, service.getId(), request.price(), now));
        }
        return ofWorker(providerId, workerId, ownerId);
    }
}
