package com.zairo.factory.vertical.auto;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AutoBookingRepository extends JpaRepository<AutoBooking, UUID> {

    Optional<AutoBooking> findByBookingId(UUID bookingId);
}
