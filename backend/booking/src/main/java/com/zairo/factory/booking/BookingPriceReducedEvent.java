package com.zairo.factory.booking;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * An appointment's agreed price went down (it moved to a cheaper worker — the customer never pays more than they
 * agreed to, and when the replacement is cheaper they pay the lower price). Payments returns whatever the customer
 * already paid above {@code newTotal}.
 */
public record BookingPriceReducedEvent(UUID bookingId, UUID userId, UUID providerId, BigDecimal oldTotal,
        BigDecimal newTotal, String currency) {
}
