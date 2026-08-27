/**
 * Business-owner-facing analytics — customer history and dashboard metrics
 * for one provider, computed from existing operational data
 * ({@code booking.Booking}, {@code payments.Payment}, {@code services.ServiceOffering},
 * {@code users.User}) rather than a separate CRM/analytics table. Same
 * read-composition shape as {@code search} (which reads the same modules
 * platform-wide); this one is scoped to a single provider and requires its
 * owner.
 */
package com.zairo.factory.providerinsights;
