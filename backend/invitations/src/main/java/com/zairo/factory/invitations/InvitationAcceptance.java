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
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

/**
 * Turns one open invitation into a real master / mechanic / cleaner / staff record. Deliberately not
 * {@code @Transactional} itself: the directory call runs in its own transaction, so when it is refused (plan
 * limit reached) only that transaction rolls back and the outcome is then recorded on the invitation —
 * a failure inside a shared transaction would leave it rollback-only and lose the FAILED marker. One
 * invitation that cannot be fulfilled never affects the others or the sign-up that triggered it.
 */
@Component
public class InvitationAcceptance {

    private final StaffInvitationRepository invitationRepository;
    private final ProviderRepository providerRepository;
    private final MasterDirectoryService masterDirectoryService;
    private final MechanicDirectoryService mechanicDirectoryService;
    private final CleanerDirectoryService cleanerDirectoryService;
    private final StaffDirectoryService staffDirectoryService;
    private final TransactionTemplate newTransaction;

    InvitationAcceptance(StaffInvitationRepository invitationRepository, ProviderRepository providerRepository,
            MasterDirectoryService masterDirectoryService, MechanicDirectoryService mechanicDirectoryService,
            CleanerDirectoryService cleanerDirectoryService, StaffDirectoryService staffDirectoryService,
            PlatformTransactionManager transactionManager) {
        this.invitationRepository = invitationRepository;
        this.providerRepository = providerRepository;
        this.masterDirectoryService = masterDirectoryService;
        this.mechanicDirectoryService = mechanicDirectoryService;
        this.cleanerDirectoryService = cleanerDirectoryService;
        this.staffDirectoryService = staffDirectoryService;
        this.newTransaction = new TransactionTemplate(transactionManager);
        this.newTransaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

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
            // Own transaction (REQUIRES_NEW): a refusal rolls back only this attempt, and it also works when
            // the sign-up's transaction is still bound to the thread (after-commit phase).
            newTransaction.executeWithoutResult(status -> {
                switch (invitation.getKind()) {
                    case MASTER -> masterDirectoryService.createMasterFromUser(providerId, userId, owner);
                    case MECHANIC -> mechanicDirectoryService.createMechanicFromUser(providerId, userId, owner);
                    case CLEANER -> cleanerDirectoryService.createCleanerFromUser(providerId, userId, owner);
                    case STAFF -> staffDirectoryService.createStaffFromUser(providerId, userId, owner);
                }
            });
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
        newTransaction.executeWithoutResult(status -> invitationRepository.save(invitation));
    }
}
