package com.zairo.factory.invitations;

import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.staff.StaffDirectoryService;
import com.zairo.factory.vertical.auto.MechanicDirectoryService;
import com.zairo.factory.vertical.beauty.MasterDirectoryService;
import com.zairo.factory.vertical.cleaning.CleanerDirectoryService;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Turns one open invitation into a real master / mechanic / cleaner / staff record. Each invitation runs in its
 * own transaction ({@code REQUIRES_NEW}) so one that cannot be fulfilled (plan limit reached, business gone)
 * is marked failed without affecting the others — or the sign-up that triggered it.
 */
@Component
public class InvitationAcceptance {

    private final StaffInvitationRepository invitationRepository;
    private final ProviderRepository providerRepository;
    private final MasterDirectoryService masterDirectoryService;
    private final MechanicDirectoryService mechanicDirectoryService;
    private final CleanerDirectoryService cleanerDirectoryService;
    private final StaffDirectoryService staffDirectoryService;

    InvitationAcceptance(StaffInvitationRepository invitationRepository, ProviderRepository providerRepository,
            MasterDirectoryService masterDirectoryService, MechanicDirectoryService mechanicDirectoryService,
            CleanerDirectoryService cleanerDirectoryService, StaffDirectoryService staffDirectoryService) {
        this.invitationRepository = invitationRepository;
        this.providerRepository = providerRepository;
        this.masterDirectoryService = masterDirectoryService;
        this.mechanicDirectoryService = mechanicDirectoryService;
        this.cleanerDirectoryService = cleanerDirectoryService;
        this.staffDirectoryService = staffDirectoryService;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void accept(UUID invitationId, UUID userId) {
        StaffInvitation invitation = invitationRepository.findById(invitationId).orElse(null);
        if (invitation == null || invitation.getStatus() != InvitationStatus.PENDING) {
            return;
        }
        Provider provider = providerRepository.findById(invitation.getProviderId()).orElse(null);
        if (provider == null) {
            invitation.fail("Business no longer exists");
            invitationRepository.save(invitation);
            return;
        }
        // The business owner is the requester, so ownership and the plan's staff limit apply as if they had
        // added the person by hand.
        UUID owner = provider.getOwnerUserId();
        UUID providerId = provider.getId();
        try {
            switch (invitation.getKind()) {
                case MASTER -> masterDirectoryService.createMasterFromUser(providerId, userId, owner);
                case MECHANIC -> mechanicDirectoryService.createMechanicFromUser(providerId, userId, owner);
                case CLEANER -> cleanerDirectoryService.createCleanerFromUser(providerId, userId, owner);
                case STAFF -> staffDirectoryService.createStaffFromUser(providerId, userId, owner);
            }
            invitation.accept(userId);
        } catch (ResponseStatusException e) {
            if (e.getStatusCode() == HttpStatus.CONFLICT) {
                invitation.accept(userId); // already attached — nothing left to do
            } else {
                invitation.fail(e.getReason());
            }
        } catch (RuntimeException e) {
            // e.g. the plan's staff limit (a dedicated exception, not a ResponseStatusException)
            invitation.fail(e.getMessage());
        }
        invitationRepository.save(invitation);
    }
}
