package com.zairo.factory.customerintelligence;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CustomerIntelligenceDtos {

    private CustomerIntelligenceDtos() {
    }

    /**
     * The customer's own view of their platform-wide profile -- deliberately
     * narrower than {@link CustomerProfile} itself: no raw {@code
     * customerValueScore} (that is business-facing intelligence about the
     * customer, not something to hand back to them -- see this module's own
     * task brief on not exposing internal scoring unnecessarily) and no
     * cancellation/no-show counts framed as a "score" a customer could feel
     * penalized by. Just the useful, self-evident facts.
     */
    public record MyIntelligenceResponse(
            int totalCompletedBookings,
            Instant lastVisitAt,
            Instant nextExpectedVisitAt,
            Integer averageVisitIntervalDays,
            List<String> preferredBookingDays,
            String preferredBookingTimeRange,
            UUID favouriteProviderId,
            UUID favouriteServiceId,
            String retentionStatus) {

        static MyIntelligenceResponse from(CustomerProfile profile) {
            return new MyIntelligenceResponse(profile.getTotalCompletedBookings(),
                    profile.getLastCompletedBookingAt(), profile.getNextExpectedVisitAt(),
                    profile.getAverageVisitIntervalDays(),
                    profile.getPreferredBookingDays().stream().map(Enum::name).toList(),
                    profile.getPreferredBookingTimeRange().name(), profile.getFavouriteProviderId(),
                    profile.getFavouriteServiceId(), profile.getRetentionStatus().name());
        }
    }

    /**
     * The business-admin view of one of their customers -- everything a
     * business owner is meant to see per this module's own task brief
     * (visit history, favourites, cadence, attendance, value, retention),
     * scoped to this one business only.
     */
    public record BusinessCustomerIntelligenceResponse(
            UUID userId,
            UUID providerId,
            int totalBookings,
            int completedBookings,
            int cancelledBookings,
            int noShows,
            BigDecimal totalSpent,
            String currency,
            BigDecimal averageBookingValue,
            Instant firstVisitAt,
            Instant lastVisitAt,
            Integer averageVisitIntervalDays,
            Instant nextExpectedVisitAt,
            List<String> preferredBookingDays,
            String preferredBookingTimeRange,
            Double attendanceRate,
            double cancellationRate,
            String retentionStatus,
            UUID favouriteEmployeeId,
            UUID favouriteServiceId,
            BigDecimal relationshipScore,
            Instant lastCalculatedAt) {

        static BusinessCustomerIntelligenceResponse from(CustomerProviderProfile profile) {
            return new BusinessCustomerIntelligenceResponse(profile.getUserId(), profile.getProviderId(),
                    profile.getTotalBookings(), profile.getCompletedBookings(), profile.getCancelledBookings(),
                    profile.getNoShows(), profile.getTotalSpent(), profile.getCurrency(),
                    profile.getAverageBookingValue(), profile.getFirstVisitAt(), profile.getLastVisitAt(),
                    profile.getAverageVisitIntervalDays(), profile.getNextExpectedVisitAt(),
                    profile.getPreferredBookingDays().stream().map(Enum::name).toList(),
                    profile.getPreferredBookingTimeRange().name(), profile.getAttendanceRate(),
                    profile.getCancellationRate(), profile.getRetentionStatus().name(),
                    profile.getFavouriteEmployeeId(), profile.getFavouriteServiceId(), profile.getRelationshipScore(),
                    profile.getLastCalculatedAt());
        }
    }
}
