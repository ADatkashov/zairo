package com.zairo.factory.vertical.beauty;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MasterBookingRepository extends JpaRepository<MasterBooking, UUID> {

    Optional<MasterBooking> findByBookingId(UUID bookingId);
}
