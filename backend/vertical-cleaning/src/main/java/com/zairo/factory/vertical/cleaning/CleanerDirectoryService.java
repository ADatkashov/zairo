package com.zairo.factory.vertical.cleaning;

import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.subscriptions.SubscriptionLimitService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/** Cleaner CRUD and which services a cleaner can perform. Booking itself lives in {@link CleaningBookingService}. */
@Service
public class CleanerDirectoryService {

    private static final String CLEANING_VERTICAL = "cleaning";

    private final CleanerRepository cleanerRepository;
    private final CleanerServiceLinkRepository cleanerServiceLinkRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;
    private final SubscriptionLimitService subscriptionLimitService;

    public CleanerDirectoryService(CleanerRepository cleanerRepository,
            CleanerServiceLinkRepository cleanerServiceLinkRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderOwnership providerOwnership,
            SubscriptionLimitService subscriptionLimitService) {
        this.cleanerRepository = cleanerRepository;
        this.cleanerServiceLinkRepository = cleanerServiceLinkRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
        this.subscriptionLimitService = subscriptionLimitService;
    }

    /**
     * The one place this module reads {@code Provider.vertical}: refusing to
     * attach a cleaner to a provider that isn't actually in the cleaning
     * vertical — same reasoning as vertical-beauty's
     * {@code MasterDirectoryService.createMaster}. Owner-only.
     */
    @Transactional
    public Cleaner createCleaner(UUID providerId, String displayName, String bio, String photoUrl,
            UUID requestingUserId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        providerOwnership.requireOwner(providerId, requestingUserId);
        if (!isCleaningVertical(provider)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Provider is not in the cleaning vertical: "
                    + providerId);
        }
        subscriptionLimitService.checkCanAddStaff(provider.getOwnerUserId(),
                (int) cleanerRepository.countByProviderId(providerId));

        Cleaner cleaner = new Cleaner(UUID.randomUUID(), providerId, displayName, bio, photoUrl, true,
                Instant.now());
        return cleanerRepository.save(cleaner);
    }

    /**
     * Case/whitespace-tolerant on purpose, same as vertical-beauty's
     * {@code isBeautyVertical} — {@code Provider.vertical} is free,
     * unvalidated text (Core never checks it).
     */
    private boolean isCleaningVertical(Provider provider) {
        return provider.getVertical() != null && CLEANING_VERTICAL.equalsIgnoreCase(provider.getVertical().trim());
    }

    /**
     * Active cleaners by default — Business Admin passes includeInactive=true
     * to also show deactivated cleaners (with a reactivate action).
     */
    public List<Cleaner> listCleanersByProvider(UUID providerId, boolean includeInactive) {
        return includeInactive ? cleanerRepository.findByProviderId(providerId)
                : cleanerRepository.findByProviderIdAndActiveTrue(providerId);
    }

    public Cleaner getCleaner(UUID cleanerId) {
        return cleanerRepository.findById(cleanerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Cleaner not found: "
                        + cleanerId));
    }

    /** Idempotent — linking an already-linked service is a no-op, same as vertical-beauty's linkService. */
    @Transactional
    public void linkService(UUID cleanerId, UUID serviceId, UUID requestingUserId) {
        Cleaner cleaner = getCleaner(cleanerId);
        providerOwnership.requireOwner(cleaner.getProviderId(), requestingUserId);
        ServiceOffering service = serviceOfferingRepository.findById(serviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: "
                        + serviceId));
        if (!service.getProviderId().equals(cleaner.getProviderId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Service belongs to a different provider than the cleaner: " + serviceId);
        }
        if (cleanerServiceLinkRepository.existsByCleanerIdAndServiceId(cleanerId, serviceId)) {
            return;
        }
        cleanerServiceLinkRepository.save(new CleanerServiceLink(UUID.randomUUID(), cleanerId, serviceId));
    }

    /** Idempotent — unlinking a service that isn't linked is a no-op. */
    @Transactional
    public void unlinkService(UUID cleanerId, UUID serviceId, UUID requestingUserId) {
        Cleaner cleaner = getCleaner(cleanerId);
        providerOwnership.requireOwner(cleaner.getProviderId(), requestingUserId);
        cleanerServiceLinkRepository.deleteByCleanerIdAndServiceId(cleanerId, serviceId);
    }

    public List<ServiceOffering> listServices(UUID cleanerId) {
        getCleaner(cleanerId);
        List<UUID> serviceIds = cleanerServiceLinkRepository.findByCleanerId(cleanerId).stream()
                .map(CleanerServiceLink::getServiceId).toList();
        return serviceOfferingRepository.findAllById(serviceIds);
    }

    /** Idempotent — deactivating an already-inactive (or missing) cleaner is a no-op. */
    @Transactional
    public void deactivateCleaner(UUID cleanerId, UUID requestingUserId) {
        cleanerRepository.findById(cleanerId).ifPresent(cleaner -> {
            providerOwnership.requireOwner(cleaner.getProviderId(), requestingUserId);
            cleaner.deactivate();
            cleanerRepository.save(cleaner);
        });
    }

    /** Owner-only, idempotent — undoes deactivateCleaner(). */
    @Transactional
    public Cleaner reactivateCleaner(UUID cleanerId, UUID requestingUserId) {
        Cleaner cleaner = getCleaner(cleanerId);
        providerOwnership.requireOwner(cleaner.getProviderId(), requestingUserId);
        cleaner.reactivate();
        return cleanerRepository.save(cleaner);
    }
}
