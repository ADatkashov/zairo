package com.zairo.factory.booking;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * "Your booking is in about an hour" — runs every 5 minutes, cheap window
 * query (usually zero matching rows), same cadence reasoning as {@link
 * BookingPaymentTimeoutJob}: frequent enough that the reminder lands close
 * to the hour-before mark without needing per-booking precision scheduling.
 */
@Component
class BookingReminderJob {

    private static final Duration REMINDER_LEAD_TIME = Duration.ofHours(1);

    private final BookingService bookingService;
    private final Clock clock;

    BookingReminderJob(BookingService bookingService, Clock clock) {
        this.bookingService = bookingService;
        this.clock = clock;
    }

    @Scheduled(fixedDelay = 300_000)
    void sendDueReminders() {
        Instant now = clock.instant();
        bookingService.sendDueReminders(now, now.plus(REMINDER_LEAD_TIME));
    }
}
