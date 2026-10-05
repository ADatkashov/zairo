package com.zairo.factory.invitations;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StaffInvitationRepository extends JpaRepository<StaffInvitation, UUID> {

    List<StaffInvitation> findByProviderIdAndStatusOrderByCreatedAtDesc(UUID providerId, InvitationStatus status);

    List<StaffInvitation> findByPhoneAndStatus(String phone, InvitationStatus status);

    boolean existsByProviderIdAndPhoneAndStatus(UUID providerId, String phone, InvitationStatus status);
}
