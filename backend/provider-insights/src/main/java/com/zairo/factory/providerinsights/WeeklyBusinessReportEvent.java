package com.zairo.factory.providerinsights;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Published once a week per business that had bookings in the week (see {@link WeeklyBusinessReportService});
 * notifications emails it to the owner. The figures are the same as the owner's own analytics overview for that week,
 * next to the week before it, so the owner sees the direction and not just a number.
 *
 * @param averageRating average of the week's visible reviews; null when nobody reviewed
 * @param previousTotalBookings bookings in the seven days before this week
 * @param previousRevenue revenue in the seven days before this week
 */
public record WeeklyBusinessReportEvent(UUID providerId, String providerName, Instant from, Instant to,
        long totalBookings, long completedBookings, long cancelledBookings, long noShowBookings,
        BigDecimal totalRevenue, String currency, long previousTotalBookings, BigDecimal previousRevenue,
        Double averageRating, long newReviews) {
}
