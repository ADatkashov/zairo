package com.zairo.factory.vertical.beauty;

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

/** Master/portfolio CRUD and which services a master can perform. Booking itself lives in {@link BeautyBookingService}. */
@Service
public class MasterDirectoryService {

    private static final String BEAUTY_VERTICAL = "beauty";

    private final MasterRepository masterRepository;
    private final PortfolioItemRepository portfolioItemRepository;
    private final MasterServiceLinkRepository masterServiceLinkRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;
    private final SubscriptionLimitService subscriptionLimitService;

    public MasterDirectoryService(MasterRepository masterRepository, PortfolioItemRepository portfolioItemRepository,
            MasterServiceLinkRepository masterServiceLinkRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderOwnership providerOwnership,
            SubscriptionLimitService subscriptionLimitService) {
        this.masterRepository = masterRepository;
        this.portfolioItemRepository = portfolioItemRepository;
        this.masterServiceLinkRepository = masterServiceLinkRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
        this.subscriptionLimitService = subscriptionLimitService;
    }

    /**
     * The one place this module reads {@code Provider.vertical}: refusing to
     * attach a master to a provider that isn't actually in the beauty
     * vertical. This is the vertical module checking its own precondition,
     * not Core branching on vertical — Core (providers module) still never
     * looks at this string itself, and never validates it either (see
     * {@code Provider}'s own doc comment: "stored and returned as-is").
     * Owner-only.
     */
    @Transactional
    public Master createMaster(UUID providerId, String displayName, String bio, String photoUrl,
            UUID requestingUserId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        providerOwnership.requireOwner(providerId, requestingUserId);
        if (!isBeautyVertical(provider)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Provider is not in the beauty vertical: "
                    + providerId);
        }
        subscriptionLimitService.checkCanAddStaff(provider.getOwnerUserId(),
                (int) masterRepository.countByProviderId(providerId));

        Master master = new Master(UUID.randomUUID(), providerId, displayName, bio, photoUrl, true, Instant.now());
        return masterRepository.save(master);
    }

    /**
     * Case/whitespace-tolerant on purpose: {@code Provider.vertical} is
     * free, unvalidated text (Core deliberately never checks it — see
     * createMaster's javadoc), so a provider owner typing "Beauty" or
     * " beauty " when creating their salon is a real possibility, not a
     * hypothetical. A future second vertical (e.g. "auto") gets the exact
     * same tiny pattern in its own module — this one check never has to
     * change for that to work, and never needs to know "auto" exists.
     */
    private boolean isBeautyVertical(Provider provider) {
        return provider.getVertical() != null && BEAUTY_VERTICAL.equalsIgnoreCase(provider.getVertical().trim());
    }

    /**
     * Active masters by default — Business Admin passes includeInactive=true
     * to also show deactivated masters (with a reactivate action); nothing
     * else (booking, the customer app) needs to see them.
     */
    public List<Master> listMastersByProvider(UUID providerId, boolean includeInactive) {
        return includeInactive ? masterRepository.findByProviderId(providerId)
                : masterRepository.findByProviderIdAndActiveTrue(providerId);
    }

    public Master getMaster(UUID masterId) {
        return masterRepository.findById(masterId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Master not found: " + masterId));
    }

    @Transactional
    public PortfolioItem addPortfolioItem(UUID masterId, String imageUrl, String caption, UUID requestingUserId) {
        Master master = getMaster(masterId);
        providerOwnership.requireOwner(master.getProviderId(), requestingUserId);
        PortfolioItem item = new PortfolioItem(UUID.randomUUID(), masterId, imageUrl, caption, Instant.now());
        return portfolioItemRepository.save(item);
    }

    public List<PortfolioItem> listPortfolio(UUID masterId) {
        getMaster(masterId);
        return portfolioItemRepository.findByMasterId(masterId);
    }

    /** Idempotent — linking an already-linked service is a no-op, same as favorites' add. */
    @Transactional
    public void linkService(UUID masterId, UUID serviceId, UUID requestingUserId) {
        Master master = getMaster(masterId);
        providerOwnership.requireOwner(master.getProviderId(), requestingUserId);
        ServiceOffering service = serviceOfferingRepository.findById(serviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: "
                        + serviceId));
        if (!service.getProviderId().equals(master.getProviderId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Service belongs to a different provider than the master: " + serviceId);
        }
        if (masterServiceLinkRepository.existsByMasterIdAndServiceId(masterId, serviceId)) {
            return;
        }
        masterServiceLinkRepository.save(new MasterServiceLink(UUID.randomUUID(), masterId, serviceId));
    }

    /** Idempotent — unlinking a service that isn't linked is a no-op. */
    @Transactional
    public void unlinkService(UUID masterId, UUID serviceId, UUID requestingUserId) {
        Master master = getMaster(masterId);
        providerOwnership.requireOwner(master.getProviderId(), requestingUserId);
        masterServiceLinkRepository.deleteByMasterIdAndServiceId(masterId, serviceId);
    }

    public List<ServiceOffering> listServices(UUID masterId) {
        getMaster(masterId);
        List<UUID> serviceIds = masterServiceLinkRepository.findByMasterId(masterId).stream()
                .map(MasterServiceLink::getServiceId).toList();
        return serviceOfferingRepository.findAllById(serviceIds);
    }

    /** Idempotent — deactivating an already-inactive (or missing) master is a no-op. */
    @Transactional
    public void deactivateMaster(UUID masterId, UUID requestingUserId) {
        masterRepository.findById(masterId).ifPresent(master -> {
            providerOwnership.requireOwner(master.getProviderId(), requestingUserId);
            master.deactivate();
            masterRepository.save(master);
        });
    }

    /** Owner-only, idempotent — undoes deactivateMaster(). */
    @Transactional
    public Master reactivateMaster(UUID masterId, UUID requestingUserId) {
        Master master = getMaster(masterId);
        providerOwnership.requireOwner(master.getProviderId(), requestingUserId);
        master.reactivate();
        return masterRepository.save(master);
    }
}
