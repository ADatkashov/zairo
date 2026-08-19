/**
 * Marketplace Engine (Layer 1): Booking, Availability, TimeSlot. Exposes
 * extension points ({@code Bookable}, {@code AvailabilityProvider},
 * {@code PricingStrategy}) that vertical modules implement — this module
 * must never branch on vertical type.
 */
package com.zairo.factory.booking;
