package com.zairo.factory.providerinsights;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Published once a week per business that had bookings in the week (see {@link WeeklyBusinessReportService});
 * notifications emails it to the owner. The figures are the same as the owner's own analytics overview for that week.
 */
public record WeeklyBusinessReportEvent(UUID providerId, String providerName, Instant from, Instant to,
        long totalBookings, long completedBookings, long cancelledBookings, long noShowBookings,
        BigDecimal totalRevenue, String currency) {
}
