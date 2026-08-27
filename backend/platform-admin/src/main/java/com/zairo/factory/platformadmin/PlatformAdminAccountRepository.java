package com.zairo.factory.platformadmin;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PlatformAdminAccountRepository extends JpaRepository<PlatformAdminAccount, UUID> {

    Optional<PlatformAdminAccount> findByEmail(String email);
}
