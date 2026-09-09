package com.zairo.factory.staff;

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

/**
 * Staff CRUD and which services a staff member can perform. Booking itself
 * lives in {@link StaffBookingService}. Unlike vertical-beauty's
 * {@code MasterDirectoryService} (and its auto/cleaning equivalents),
 * {@link #createStaff} reads no {@code Provider.vertical} at all — any
 * provider, in any category, can have staff. See this package's own doc
 * comment for why that's a deliberate difference, not an oversight.
 */
@Service
public class StaffDirectoryService {

    private final StaffRepository staffRepository;
    private final StaffServiceLinkRepository staffServiceLinkRepository;
    private final ProviderRepository providerRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final ProviderOwnership providerOwnership;
    private final SubscriptionLimitService subscriptionLimitService;

    public StaffDirectoryService(StaffRepository staffRepository,
            StaffServiceLinkRepository staffServiceLinkRepository, ProviderRepository providerRepository,
            ServiceOfferingRepository serviceOfferingRepository, ProviderOwnership providerOwnership,
            SubscriptionLimitService subscriptionLimitService) {
        this.staffRepository = staffRepository;
        this.staffServiceLinkRepository = staffServiceLinkRepository;
        this.providerRepository = providerRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.providerOwnership = providerOwnership;
        this.subscriptionLimitService = subscriptionLimitService;
    }

    @Transactional
    public Staff createStaff(UUID providerId, String displayName, String bio, String photoUrl,
            UUID requestingUserId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: "
                        + providerId));
        providerOwnership.requireOwner(providerId, requestingUserId);
        subscriptionLimitService.checkCanAddStaff(provider.getOwnerUserId(),
                (int) staffRepository.countByProviderId(providerId));

        Staff staff = new Staff(UUID.randomUUID(), providerId, displayName, bio, photoUrl, true, Instant.now());
        return staffRepository.save(staff);
    }

    /**
     * Active staff by default — a management UI passes includeInactive=true
     * to also show deactivated staff (with a reactivate action).
     */
    public List<Staff> listStaffByProvider(UUID providerId, boolean includeInactive) {
        return includeInactive ? staffRepository.findByProviderId(providerId)
                : staffRepository.findByProviderIdAndActiveTrue(providerId);
    }

    public Staff getStaff(UUID staffId) {
        return staffRepository.findById(staffId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Staff not found: " + staffId));
    }

    /** Idempotent — linking an already-linked service is a no-op, same as vertical-beauty's linkService. */
    @Transactional
    public void linkService(UUID staffId, UUID serviceId, UUID requestingUserId) {
        Staff staff = getStaff(staffId);
        providerOwnership.requireOwner(staff.getProviderId(), requestingUserId);
        ServiceOffering service = serviceOfferingRepository.findById(serviceId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found: "
                        + serviceId));
        if (!service.getProviderId().equals(staff.getProviderId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Service belongs to a different provider than the staff member: " + serviceId);
        }
        if (staffServiceLinkRepository.existsByStaffIdAndServiceId(staffId, serviceId)) {
            return;
        }
        staffServiceLinkRepository.save(new StaffServiceLink(UUID.randomUUID(), staffId, serviceId));
    }

    /** Idempotent — unlinking a service that isn't linked is a no-op. */
    @Transactional
    public void unlinkService(UUID staffId, UUID serviceId, UUID requestingUserId) {
        Staff staff = getStaff(staffId);
        providerOwnership.requireOwner(staff.getProviderId(), requestingUserId);
        staffServiceLinkRepository.deleteByStaffIdAndServiceId(staffId, serviceId);
    }

    public List<ServiceOffering> listServices(UUID staffId) {
        getStaff(staffId);
        List<UUID> serviceIds = staffServiceLinkRepository.findByStaffId(staffId).stream()
                .map(StaffServiceLink::getServiceId).toList();
        return serviceOfferingRepository.findAllById(serviceIds);
    }

    /** Owner-only — replaces the staff member's photo (null/blank removes it). */
    @Transactional
    public Staff updateStaffPhoto(UUID staffId, String photoUrl, UUID requestingUserId) {
        Staff staff = getStaff(staffId);
        providerOwnership.requireOwner(staff.getProviderId(), requestingUserId);
        staff.updatePhoto(photoUrl);
        return staffRepository.save(staff);
    }

    /** Idempotent — deactivating an already-inactive (or missing) staff member is a no-op. */
    @Transactional
    public void deactivateStaff(UUID staffId, UUID requestingUserId) {
        staffRepository.findById(staffId).ifPresent(staff -> {
            providerOwnership.requireOwner(staff.getProviderId(), requestingUserId);
            staff.deactivate();
            staffRepository.save(staff);
        });
    }

    /** Owner-only, idempotent — undoes deactivateStaff(). */
    @Transactional
    public Staff reactivateStaff(UUID staffId, UUID requestingUserId) {
        Staff staff = getStaff(staffId);
        providerOwnership.requireOwner(staff.getProviderId(), requestingUserId);
        staff.reactivate();
        return staffRepository.save(staff);
    }
}
