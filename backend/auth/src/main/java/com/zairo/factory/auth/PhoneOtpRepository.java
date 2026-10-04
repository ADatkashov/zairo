package com.zairo.factory.auth;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/**
 * Extends the bare {@link Repository} marker (no inherited methods) rather
 * than {@code JpaRepository}, and declares only the handful of methods
 * {@link PhoneOtpService} actually uses — Spring Data JPA still generates a
 * full implementation from these at runtime, but the small, explicit
 * surface is also cheap to hand-implement as an in-memory fake for
 * PhoneOtpServiceTest, no DB required (see that test's FakePhoneOtpRepository).
 */
interface PhoneOtpRepository extends Repository<PhoneOtp, UUID> {

    PhoneOtp save(PhoneOtp otp);

    Optional<PhoneOtp> findTopByPhoneOrderByCreatedAtDesc(String phone);

    long countByPhoneAndCreatedAtAfter(String phone, Instant since);

    long countByRequestIpAndCreatedAtAfter(String requestIp, Instant since);

    long countByCreatedAtAfter(Instant since);

    /**
     * Atomic, race-safe consumption: two concurrent verify calls for the
     * same code both read {@code consumedAt == null}, but only one {@code
     * UPDATE ... WHERE consumed_at is null} can actually flip a row from
     * unconsumed to consumed — the loser gets 0 rows affected and must
     * treat the code as already used (see PhoneOtpService.verify). A
     * plain "read then check then write" in application code can't give
     * this guarantee; the database's row-level locking on the UPDATE is
     * what does.
     */
    @Modifying
    @Query("update PhoneOtp o set o.consumedAt = :now where o.id = :id and o.consumedAt is null")
    int consume(@Param("id") UUID id, @Param("now") Instant now);

    @Modifying
    @Query("update PhoneOtp o set o.attempts = o.attempts + 1 where o.id = :id")
    void incrementAttempts(@Param("id") UUID id);
}
