package com.zairo.factory.payments;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BusinessPayoutRepository extends JpaRepository<BusinessPayout, UUID> {

    Optional<BusinessPayout> findByBookingId(UUID bookingId);

    Optional<BusinessPayout> findByPaymentId(UUID paymentId);

    List<BusinessPayout> findByProviderIdOrderByCreatedAtDesc(UUID providerId);

    List<BusinessPayout> findByStatusOrderByCreatedAtDesc(BusinessPayoutStatus status);
}
