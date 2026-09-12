/**
 * Customer Intelligence: the foundation that turns raw booking history into
 * "who is this customer, really" -- visit cadence, spend, preferences,
 * attendance, and a deterministic retention/value read -- so every other
 * ZAIRO feature that needs to reason about a customer (Revenue Engine
 * strategies today, a future Business AI Advisor, personalized
 * recommendations, VIP retention, ...) reads one cheap, precomputed answer
 * instead of re-deriving it from {@code Booking} itself.
 *
 * <h2>Three scopes, one shape</h2>
 * ZAIRO's own vocabulary: a {@code providers.Provider} is a business, and
 * {@code booking.AvailabilitySlot.employeeId} is the specific master/
 * mechanic/cleaner who served it (opaque, vertical-owned -- see that
 * field's own doc comment). Customer Intelligence mirrors that with three
 * aggregates, cheapest/broadest to narrowest:
 * <ul>
 *   <li>{@link com.zairo.factory.customerintelligence.CustomerProfile} --
 *   one row per {@code userId}: the customer's behaviour across every
 *   business on the platform.
 *   <li>{@link com.zairo.factory.customerintelligence.CustomerProviderProfile}
 *   -- one row per ({@code userId}, {@code providerId}): the relationship
 *   with one specific business (a customer can be a VIP at one salon and a
 *   stranger at another).
 *   <li>{@link com.zairo.factory.customerintelligence.CustomerEmployeeProfile}
 *   -- one row per ({@code userId}, {@code providerId}, {@code employeeId}):
 *   the relationship with one specific master/mechanic/cleaner, the signal
 *   Smart Fill's own {@code PREVIOUSLY_BOOKED_SAME_EMPLOYEE} factor already
 *   gestures at with a cheap existence check.
 * </ul>
 * All three share the same calculation core ({@code VisitAggregate}) and
 * the same data-quality rule: only {@code COMPLETED} bookings count as real
 * visits/spend; {@code CANCELLED} and {@code NO_SHOW} never do (see each
 * calculator's own doc comment).
 *
 * <h2>Computed on events, not on read</h2>
 * A profile is recalculated -- fully, from {@code Booking}/{@code
 * AvailabilitySlot}, never incrementally -- whenever {@link
 * com.zairo.factory.customerintelligence.CustomerIntelligenceBookingListener}
 * hears {@code BookingConfirmedEvent}/{@code BookingCompletedEvent}/{@code
 * BookingCancelledEvent}/{@code BookingNoShowEvent} for that customer (see
 * ADR-0002 -- same in-process domain event pattern every other module here
 * uses). Recomputing from source rather than incrementing counters is what
 * makes recalculation naturally idempotent -- a duplicated event, or an
 * explicit re-{@link com.zairo.factory.customerintelligence.CustomerIntelligenceService#recalculateProfile}
 * call, always lands on the same answer instead of double-counting.
 * {@link com.zairo.factory.customerintelligence.CustomerIntelligenceService}'s
 * read methods are a read-through cache on top of that: a profile that's
 * never been computed (pre-existing data, or a user with no events yet) is
 * calculated once on first read and persisted, not recomputed on every
 * subsequent call.
 *
 * <h2>Revenue Engine integration</h2>
 * This module owns no scoring/campaign logic of its own and never depends
 * on {@code revenue-engine}, {@code smart-fill}, or {@code rebook-engine} --
 * the dependency runs one way. A strategy that wants customer context
 * (previous visits, cadence, attendance, value, relationship strength) for
 * one business's candidate pool calls {@link
 * com.zairo.factory.customerintelligence.CustomerIntelligenceService#findProviderProfiles}
 * once, in bulk, the same "one query per data source, no N+1" discipline
 * {@code smartfill.CandidateFinder} already follows for its other signals.
 * {@code smart-fill}'s {@code CandidateFinder} does exactly this today,
 * feeding retention status into a new, purely additive {@code
 * ScoringFactor.DUE_FOR_REBOOKING} -- see that module's own changes.
 *
 * <h2>Deliberately not built here</h2>
 * No ML model, no exchange-rate conversion (spend aggregates assume a
 * single currency, the same limitation {@code revenueengine
 * .RevenueAttributionService} already has), no marketing/notification
 * side effects (a customer crossing into {@code AT_RISK} does not, by
 * itself, send anything -- that is a future strategy's job, not this
 * foundation's). {@link com.zairo.factory.customerintelligence.CustomerValueCalculator}
 * is an explicit, transparent, configurable formula, not a predictive
 * model -- swapping it for one later is a new implementation behind the
 * same seam, not a rewrite of this module.
 */
package com.zairo.factory.customerintelligence;
