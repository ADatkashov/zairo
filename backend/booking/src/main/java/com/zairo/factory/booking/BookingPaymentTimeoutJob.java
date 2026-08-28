package com.zairo.factory.booking;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * The sweep side of {@link BookingStatus#PENDING_PAYMENT} — a booking that
 * never got a successful payment (customer abandoned checkout, a real
 * provider's redirect never came back, a webhook that will simply never
 * arrive) can't sit claiming its slot forever. Runs every minute — cheap
 * (an indexed query plus, usually, zero matching rows) and frequent enough
 * that a real customer's slot isn't held hostage by someone else's
 * abandoned checkout for long, unlike {@link SubscriptionRenewalJob}'s
 * once-a-day cadence which suits a billing cycle, not a live booking flow.
 */
@Component
class BookingPaymentTimeoutJob {

    private static final Logger log = LoggerFactory.getLogger(BookingPaymentTimeoutJob.class);

    private final BookingRepository bookingRepository;
    private final BookingService bookingService;
    private final Clock clock;
    private final int timeoutMinutes;

    BookingPaymentTimeoutJob(BookingRepository bookingRepository, BookingService bookingService, Clock clock,
            @Value("${booking.payment-timeout-minutes:15}") int timeoutMinutes) {
        this.bookingRepository = bookingRepository;
        this.bookingService = bookingService;
        this.clock = clock;
        this.timeoutMinutes = timeoutMinutes;
    }

    @Scheduled(fixedDelay = 60_000)
    void cancelTimedOutBookings() {
        Instant cutoff = clock.instant().minusSeconds(timeoutMinutes * 60L);
        List<Booking> expired = bookingRepository.findByStatusAndCreatedAtBefore(BookingStatus.PENDING_PAYMENT,
                cutoff);
        for (Booking booking : expired) {
            try {
                // cancelUnpaidBooking re-checks status itself (idempotent) —
                // a payment (or a late webhook, see
                // payments.PaymentWebhookProcessor) may have confirmed this
                // exact booking between the query above and this call.
                bookingService.cancelUnpaidBooking(booking.getId(), "Payment not completed within "
                        + timeoutMinutes + " minutes");
            } catch (RuntimeException e) {
                log.error("Failed to cancel timed-out unpaid booking {}: {}", booking.getId(), e.getMessage(), e);
            }
        }
    }
}
