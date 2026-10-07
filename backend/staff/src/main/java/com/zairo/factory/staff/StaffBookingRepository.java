package com.zairo.factory.staff;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StaffBookingRepository extends JpaRepository<StaffBooking, UUID> {

    Optional<StaffBooking> findByBookingId(UUID bookingId);
}
