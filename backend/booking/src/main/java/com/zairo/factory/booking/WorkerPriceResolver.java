package com.zairo.factory.booking;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

/**
 * Lets the business charge a different price for a specific worker. {@link BookingService} asks it when a booking
 * names the worker; no answer means the service's own price. Implemented in {@code workforce}.
 */
public interface WorkerPriceResolver {

    Optional<BigDecimal> priceFor(UUID providerId, UUID workerId, UUID serviceId);
}
