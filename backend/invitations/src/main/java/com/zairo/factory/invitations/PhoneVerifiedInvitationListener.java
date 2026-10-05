package com.zairo.factory.invitations;

import com.zairo.factory.auth.PhoneVerifiedEvent;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Attaches a person to every business that invited the phone number they just verified. */
@Component
class PhoneVerifiedInvitationListener {

    private static final Logger log = LoggerFactory.getLogger(PhoneVerifiedInvitationListener.class);

    private final StaffInvitationRepository invitationRepository;
    private final InvitationAcceptance invitationAcceptance;

    PhoneVerifiedInvitationListener(StaffInvitationRepository invitationRepository,
            InvitationAcceptance invitationAcceptance) {
        this.invitationRepository = invitationRepository;
        this.invitationAcceptance = invitationAcceptance;
    }

    // fallbackExecution: auth publishes this outside a transaction on some paths.
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    void onPhoneVerified(PhoneVerifiedEvent event) {
        List<StaffInvitation> pending = invitationRepository.findByPhoneAndStatus(event.phone(),
                InvitationStatus.PENDING);
        for (StaffInvitation invitation : pending) {
            try {
                invitationAcceptance.accept(invitation.getId(), event.userId());
            } catch (RuntimeException e) {
                // Never let an invitation problem break sign-in.
                log.warn("Could not accept invitation {}", invitation.getId(), e);
            }
        }
    }
}
