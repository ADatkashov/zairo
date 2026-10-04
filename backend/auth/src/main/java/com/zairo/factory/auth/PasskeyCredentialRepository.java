package com.zairo.factory.auth;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.repository.Repository;

/** Small explicit surface (like PhoneOtpRepository) so PasskeyServiceTest can hand-write an in-memory fake. */
interface PasskeyCredentialRepository extends Repository<PasskeyCredential, UUID> {

    PasskeyCredential save(PasskeyCredential credential);

    Optional<PasskeyCredential> findById(UUID id);

    Optional<PasskeyCredential> findByCredentialId(byte[] credentialId);

    List<PasskeyCredential> findByUserIdOrderByCreatedAtAsc(UUID userId);

    void delete(PasskeyCredential credential);
}
