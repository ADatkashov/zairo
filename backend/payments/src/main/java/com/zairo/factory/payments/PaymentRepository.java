package com.zairo.factory.payments;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, UUID> {

    Optional<Payment> findByBookingId(UUID bookingId);

    List<Payment> findByBookingIdInAndStatus(Collection<UUID> bookingIds, PaymentStatus status);

    /** The platform admin's failed-refund visibility list — see PaymentAdminController. */
    List<Payment> findByStatusOrderByCreatedAtDesc(PaymentStatus status);

    /** The platform dashboard's payment-status breakdown — see platforminsights.PlatformInsightsService. */
    long countByStatus(PaymentStatus status);
}
