package com.zairo.factory.payments;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentAllocationRepository extends JpaRepository<PaymentAllocation, UUID> {

    Optional<PaymentAllocation> findByPaymentId(UUID paymentId);

    /** The platform dashboard's marketplace-commission revenue tile — see platforminsights.PlatformInsightsService. */
    List<PaymentAllocation> findByCreatedAtBetween(Instant start, Instant end);
}
