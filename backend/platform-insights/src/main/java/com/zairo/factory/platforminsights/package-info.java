/**
 * Platform Dashboard v1 — read composition over Users/Providers/
 * Subscriptions/Bookings/Payments for the Control Center, computed fresh on
 * every call (no stored aggregates), same shape as {@code provider-insights}
 * but scoped to the whole marketplace. See
 * docs/PRODUCT_PRODUCTION_ROADMAP.md section 9 for exactly what this does
 * and doesn't cover — funnel/DAU-WAU-MAU/system-health tiles need a new
 * {@code analytics_event} model that doesn't exist yet, and are
 * deliberately not here.
 */
package com.zairo.factory.platforminsights;
