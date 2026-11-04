package com.zairo.factory.payments;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, UUID> {

    /** Get the first/main payment for a booking (backward compatibility) */
    Optional<Payment> findByBookingId(UUID bookingId);

    /** Get all payments for a booking (new: supports multiple payments per booking) */
    List<Payment> findAllByBookingId(UUID bookingId);

    /** A customer's payment history: every payment on any of their bookings, newest first — see PaymentsService.listMyPayments. */
    List<Payment> findByBookingIdInOrderByCreatedAtDesc(Collection<UUID> bookingIds);

    List<Payment> findByBookingIdInAndStatus(Collection<UUID> bookingIds, PaymentStatus status);

    /** The platform admin's failed-refund visibility list — see PaymentAdminController. */
    List<Payment> findByStatusOrderByCreatedAtDesc(PaymentStatus status);

    /** The platform dashboard's payment-status breakdown — see platforminsights.PlatformInsightsService. */
    long countByStatus(PaymentStatus status);
}
