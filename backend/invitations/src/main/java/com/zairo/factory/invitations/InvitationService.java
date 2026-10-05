package com.zairo.factory.invitations;

import com.zairo.factory.auth.PhoneNumberNormalizer;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.providers.ProviderRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class InvitationService {

    private final StaffInvitationRepository invitationRepository;
    private final ProviderRepository providerRepository;
    private final ProviderOwnership providerOwnership;
    private final PhoneNumberNormalizer phoneNumberNormalizer;

    public InvitationService(StaffInvitationRepository invitationRepository, ProviderRepository providerRepository,
            ProviderOwnership providerOwnership, PhoneNumberNormalizer phoneNumberNormalizer) {
        this.invitationRepository = invitationRepository;
        this.providerRepository = providerRepository;
        this.providerOwnership = providerOwnership;
        this.phoneNumberNormalizer = phoneNumberNormalizer;
    }

    @Transactional
    public StaffInvitation invite(UUID providerId, String rawPhone, UUID requestingUserId) {
        Provider provider = providerRepository.findById(providerId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Provider not found: " + providerId));
        providerOwnership.requireOwner(providerId, requestingUserId);
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        if (invitationRepository.existsByProviderIdAndPhoneAndStatus(providerId, phone, InvitationStatus.PENDING)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This number is already invited");
        }
        return invitationRepository.save(new StaffInvitation(UUID.randomUUID(), providerId, phone,
                InvitationKind.forVertical(provider.getVertical()), Instant.now()));
    }

    @Transactional(readOnly = true)
    public List<StaffInvitation> listPending(UUID providerId, UUID requestingUserId) {
        providerOwnership.requireOwner(providerId, requestingUserId);
        return invitationRepository.findByProviderIdAndStatusOrderByCreatedAtDesc(providerId,
                InvitationStatus.PENDING);
    }

    @Transactional
    public void cancel(UUID invitationId, UUID requestingUserId) {
        invitationRepository.findById(invitationId).ifPresent(invitation -> {
            providerOwnership.requireOwner(invitation.getProviderId(), requestingUserId);
            if (invitation.getStatus() == InvitationStatus.PENDING) {
                invitation.cancel();
                invitationRepository.save(invitation);
            }
        });
    }
}
