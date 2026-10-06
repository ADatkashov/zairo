package com.zairo.factory.staff;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StaffBookingRepository extends JpaRepository<StaffBooking, UUID> {

    Optional<StaffBooking> findByBookingId(UUID bookingId);

    List<StaffBooking> findByBookingIdIn(java.util.Collection<UUID> bookingIds);

    /**
     * Every booking that belongs to a staff member: ones made through the staff booking endpoint (a
     * {@code staff_booking} link) and ones on a slot generated for that staff member
     * ({@code availability_slot.employee_id}).
     */
    @Query(value = """
            select distinct b.id
            from booking b
            join availability_slot s on s.id = b.availability_slot_id
            left join staff_booking sb on sb.booking_id = b.id
            where sb.staff_id = :staffId or s.employee_id = :staffId
            """, nativeQuery = true)
    List<UUID> findBookingIdsForStaff(@Param("staffId") UUID staffId);
}
