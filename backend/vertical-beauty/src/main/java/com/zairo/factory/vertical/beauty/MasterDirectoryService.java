package com.zairo.factory.vertical.beauty;

import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
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

    public MasterDirectoryService(MasterRepository masterRepository, PortfolioItemRepository portfolioItemRepository,
            MasterServiceLinkRepository masterServiceLinkRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository) {
        this.masterRepository = masterRepository;
        this.portfolioItemRepository = portfolioItemRepository;
        this.masterServiceLinkRepository = masterServiceLinkRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
    }

    /**
     * The one place this module reads {@code Provider.vertical}: refusing to
     * attach a master to a provider that isn't actually in the beauty
     * vertical. This is the vertical module checking its own precondition,
     * not Core branching on vertical — Core (providers module) still never
     * looks at this string itself.
     */
    @Transactional
    public Master createMaster(UUID providerId, String displayName, String bio, String photoUrl) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        if (!BEAUTY_VERTICAL.equals(provider.getVertical())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Provider is not in the beauty vertical: "
                    + providerId);
        }

        Master master = new Master(UUID.randomUUID(), providerId, displayName, bio, photoUrl, true, Instant.now());
        return masterRepository.save(master);
    }

    public List<Master> listMastersByProvider(UUID providerId) {
        return masterRepository.findByProviderId(providerId);
    }

    public Master getMaster(UUID masterId) {
        return masterRepository.findById(masterId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Master not found: " + masterId));
    }

    @Transactional
    public PortfolioItem addPortfolioItem(UUID masterId, String imageUrl, String caption) {
        getMaster(masterId);
        PortfolioItem item = new PortfolioItem(UUID.randomUUID(), masterId, imageUrl, caption, Instant.now());
        return portfolioItemRepository.save(item);
    }

    public List<PortfolioItem> listPortfolio(UUID masterId) {
        getMaster(masterId);
        return portfolioItemRepository.findByMasterId(masterId);
    }

    /** Idempotent — linking an already-linked service is a no-op, same as favorites' add. */
    @Transactional
    public void linkService(UUID masterId, UUID serviceId) {
        Master master = getMaster(masterId);
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
    public void unlinkService(UUID masterId, UUID serviceId) {
        masterServiceLinkRepository.deleteByMasterIdAndServiceId(masterId, serviceId);
    }

    public List<ServiceOffering> listServices(UUID masterId) {
        getMaster(masterId);
        List<UUID> serviceIds = masterServiceLinkRepository.findByMasterId(masterId).stream()
                .map(MasterServiceLink::getServiceId).toList();
        return serviceOfferingRepository.findAllById(serviceIds);
    }
}
