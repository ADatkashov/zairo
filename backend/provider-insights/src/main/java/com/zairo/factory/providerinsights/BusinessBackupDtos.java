package com.zairo.factory.providerinsights;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Everything an owner needs to keep working from paper or a spreadsheet while the app is unavailable: the
 * schedule (with who is coming and how to reach them), the customer book and the service price list.
 * Contains customers' contact details, so it is only ever served to the business's own owner.
 */
public final class BusinessBackupDtos {

    private BusinessBackupDtos() {
    }

    public record BackupResponse(UUID providerId, Instant generatedAt, Instant from, Instant to,
            List<BookingRow> bookings, List<CustomerRow> customers, List<ServiceRow> services) {
    }

    /** One booking of the schedule, oldest first. Name fields are null where the server has no value. */
    public record BookingRow(UUID bookingId, Instant startsAt, Instant endsAt, String status, String serviceTitle,
            String staffName, String customerName, String customerPhone, String customerEmail, BigDecimal totalPrice,
            String currency) {
    }

    /** One customer of the business, most recent visit first. */
    public record CustomerRow(UUID userId, String name, String phone, String email, Instant lastVisitAt,
            int totalBookings, BigDecimal totalSpent, String currency, int noShows) {
    }

    public record ServiceRow(String title, int durationMinutes, BigDecimal price, String currency, boolean active) {
    }
}
