package com.zairo.factory.payments;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface PaymentRefundRequestRepository extends JpaRepository<PaymentRefundRequest, UUID> {

    Optional<PaymentRefundRequest> findByPaymentId(UUID paymentId);

    /**
     * {@code PaymentRefundOutboxProcessor}'s sweep query: rows due for
     * another attempt (PENDING, or RETRY whose backoff has elapsed) plus
     * PROCESSING rows old enough to be a crashed worker's leftovers --
     * see {@link PaymentRefundRequest#isClaimable} for the exact same
     * predicate expressed per-row (this query is the bulk-candidate
     * version; {@code claim} re-checks {@code isClaimable} under the row
     * lock before actually transitioning, so a slightly-stale/overlapping
     * candidate set here is harmless).
     */
    @Query("select r from PaymentRefundRequest r where "
            + "(r.status in (com.zairo.factory.payments.PaymentRefundRequestStatus.PENDING, "
            + "com.zairo.factory.payments.PaymentRefundRequestStatus.RETRY) "
            + "and (r.nextAttemptAt is null or r.nextAttemptAt <= :now)) "
            + "or (r.status = com.zairo.factory.payments.PaymentRefundRequestStatus.PROCESSING "
            + "and r.processingStartedAt <= :staleBefore) "
            + "order by r.createdAt asc")
    List<PaymentRefundRequest> findDue(@Param("now") Instant now, @Param("staleBefore") Instant staleBefore,
            Pageable pageable);

    /** The platform admin's refund-outbox visibility list — see PaymentAdminController. */
    List<PaymentRefundRequest> findByStatusOrderByCreatedAtDesc(PaymentRefundRequestStatus status, Pageable pageable);

    /**
     * Row-level write lock for the whole claim-or-skip / apply-outcome
     * operation -- same "serialize instead of racing" guarantee {@code
     * loyalty.LoyaltyRedemptionRepository#lockById} gives redemption
     * apply/cancel. Two concurrent workers (or a worker and a stale-reclaim
     * pass) attempting the same row would otherwise both read a claimable
     * status before either writes PROCESSING.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from PaymentRefundRequest r where r.id = :id")
    Optional<PaymentRefundRequest> lockById(@Param("id") UUID id);
}
