package com.zairo.factory.vertical.auto;

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

/** Mechanic CRUD and which services a mechanic can perform. Booking itself lives in {@link AutoBookingService}. */
@Service
public class MechanicDirectoryService {

    private static final String AUTO_VERTICAL = "auto";

    private final MechanicRepository mechanicRepository;
    private final MechanicServiceLinkRepository mechanicServiceLinkRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;
    private final SubscriptionLimitService subscriptionLimitService;

    public MechanicDirectoryService(MechanicRepository mechanicRepository,
            MechanicServiceLinkRepository mechanicServiceLinkRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderOwnership providerOwnership,
            SubscriptionLimitService subscriptionLimitService) {
        this.mechanicRepository = mechanicRepository;
        this.mechanicServiceLinkRepository = mechanicServiceLinkRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
        this.subscriptionLimitService = subscriptionLimitService;
    }

    /**
     * The one place this module reads {@code Provider.vertical}: refusing to
     * attach a mechanic to a provider that isn't actually in the auto
     * vertical — same reasoning as vertical-beauty's
     * {@code MasterDirectoryService.createMaster}. Owner-only.
     */
    @Transactional
    public Mechanic createMechanic(UUID providerId, String displayName, String bio, String photoUrl,
            UUID requestingUserId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        providerOwnership.requireOwner(providerId, requestingUserId);
        if (!isAutoVertical(provider)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Provider is not in the auto vertical: "
                    + providerId);
        }
        subscriptionLimitService.checkCanAddStaff(provider.getOwnerUserId(),
                (int) mechanicRepository.countByProviderId(providerId));

        Mechanic mechanic = new Mechanic(UUID.randomUUID(), providerId, displayName, bio, photoUrl, true,
                Instant.now());
        return mechanicRepository.save(mechanic);
    }

    /**
     * Case/whitespace-tolerant on purpose, same as vertical-beauty's
     * {@code isBeautyVertical} — {@code Provider.vertical} is free,
     * unvalidated text (Core never checks it).
     */
    private boolean isAutoVertical(Provider provider) {
        return provider.getVertical() != null && AUTO_VERTICAL.equalsIgnoreCase(provider.getVertical().trim());
    }

    /**
     * Active mechanics by default — Business Admin passes includeInactive=true
     * to also show deactivated mechanics (with a reactivate action).
     */
    public List<Mechanic> listMechanicsByProvider(UUID providerId, boolean includeInactive) {
        return includeInactive ? mechanicRepository.findByProviderId(providerId)
                : mechanicRepository.findByProviderIdAndActiveTrue(providerId);
    }

    public Mechanic getMechanic(UUID mechanicId) {
        return mechanicRepository.findById(mechanicId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Mechanic not found: "
                        + mechanicId));
    }

    /** Idempotent — linking an already-linked service is a no-op, same as vertical-beauty's linkService. */
    @Transactional
    public void linkService(UUID mechanicId, UUID serviceId, UUID requestingUserId) {
        Mechanic mechanic = getMechanic(mechanicId);
        providerOwnership.requireOwner(mechanic.getProviderId(), requestingUserId);
        ServiceOffering service = serviceOfferingRepository.findById(serviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: "
                        + serviceId));
        if (!service.getProviderId().equals(mechanic.getProviderId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Service belongs to a different provider than the mechanic: " + serviceId);
        }
        if (mechanicServiceLinkRepository.existsByMechanicIdAndServiceId(mechanicId, serviceId)) {
            return;
        }
        mechanicServiceLinkRepository.save(new MechanicServiceLink(UUID.randomUUID(), mechanicId, serviceId));
    }

    /** Idempotent — unlinking a service that isn't linked is a no-op. */
    @Transactional
    public void unlinkService(UUID mechanicId, UUID serviceId, UUID requestingUserId) {
        Mechanic mechanic = getMechanic(mechanicId);
        providerOwnership.requireOwner(mechanic.getProviderId(), requestingUserId);
        mechanicServiceLinkRepository.deleteByMechanicIdAndServiceId(mechanicId, serviceId);
    }

    public List<ServiceOffering> listServices(UUID mechanicId) {
        getMechanic(mechanicId);
        List<UUID> serviceIds = mechanicServiceLinkRepository.findByMechanicId(mechanicId).stream()
                .map(MechanicServiceLink::getServiceId).toList();
        return serviceOfferingRepository.findAllById(serviceIds);
    }

    /** Owner-only — replaces the mechanic's photo (null/blank removes it). */
    @Transactional
    public Mechanic updateMechanicPhoto(UUID mechanicId, String photoUrl, UUID requestingUserId) {
        Mechanic mechanic = getMechanic(mechanicId);
        providerOwnership.requireOwner(mechanic.getProviderId(), requestingUserId);
        mechanic.updatePhoto(photoUrl);
        return mechanicRepository.save(mechanic);
    }

    /** Idempotent — deactivating an already-inactive (or missing) mechanic is a no-op. */
    @Transactional
    public void deactivateMechanic(UUID mechanicId, UUID requestingUserId) {
        mechanicRepository.findById(mechanicId).ifPresent(mechanic -> {
            providerOwnership.requireOwner(mechanic.getProviderId(), requestingUserId);
            mechanic.deactivate();
            mechanicRepository.save(mechanic);
        });
    }

    /** Owner-only, idempotent — undoes deactivateMechanic(). */
    @Transactional
    public Mechanic reactivateMechanic(UUID mechanicId, UUID requestingUserId) {
        Mechanic mechanic = getMechanic(mechanicId);
        providerOwnership.requireOwner(mechanic.getProviderId(), requestingUserId);
        mechanic.reactivate();
        return mechanicRepository.save(mechanic);
    }
}
