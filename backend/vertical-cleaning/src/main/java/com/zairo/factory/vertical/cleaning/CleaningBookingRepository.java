package com.zairo.factory.vertical.cleaning;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CleaningBookingRepository extends JpaRepository<CleaningBooking, UUID> {

    Optional<CleaningBooking> findByBookingId(UUID bookingId);
}
