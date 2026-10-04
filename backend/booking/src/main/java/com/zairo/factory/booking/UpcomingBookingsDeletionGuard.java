package com.zairo.factory.booking;

import com.zairo.factory.auth.AccountDeletionGuard;
import java.time.Clock;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * A customer can't delete their account while they still have a live booking ahead -- cancelling one has payment and
 * refund consequences the customer should decide on, not a deletion button.
 */
@Component
class UpcomingBookingsDeletionGuard implements AccountDeletionGuard {

    private final BookingRepository bookingRepository;
    private final Clock clock;

    UpcomingBookingsDeletionGuard(BookingRepository bookingRepository, Clock clock) {
        this.bookingRepository = bookingRepository;
        this.clock = clock;
    }

    @Override
    public Optional<String> blockingReason(UUID userId) {
        return bookingRepository.countUpcomingActiveByUserId(userId, clock.instant()) > 0
                ? Optional.of("You have upcoming bookings. Cancel them or wait until they are done, then delete your account.")
                : Optional.empty();
    }
}
