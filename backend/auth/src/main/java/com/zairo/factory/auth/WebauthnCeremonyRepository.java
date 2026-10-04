package com.zairo.factory.auth;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

interface WebauthnCeremonyRepository extends Repository<WebauthnCeremony, UUID> {

    WebauthnCeremony save(WebauthnCeremony ceremony);

    Optional<WebauthnCeremony> findById(UUID id);

    /** Atomic single-use consumption — 0 rows means a concurrent request already used (or purged) it. */
    @Modifying
    @Query("delete from WebauthnCeremony c where c.id = :id")
    int consume(@Param("id") UUID id);

    @Modifying
    @Query("delete from WebauthnCeremony c where c.expiresAt < :now")
    int deleteExpired(@Param("now") Instant now);
}
