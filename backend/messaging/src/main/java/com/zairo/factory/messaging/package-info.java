/**
 * Basic 1:1 text chat between a customer and a business — one {@link
 * com.zairo.factory.messaging.Conversation} per (customer, provider) pair,
 * persisting across multiple bookings. No attachments, no group threads, no
 * read receipts — all deliberately out of scope (see
 * docs/PRODUCT_PRODUCTION_ROADMAP.md section 14/"Can Wait"). Poll-based
 * (plain REST {@code GET}), not real-time — no WebSocket infrastructure
 * exists in this project yet, and polling is the simplest thing that
 * actually closes the gap.
 *
 * <p>A {@link com.zairo.factory.messaging.Message} may optionally carry the
 * booking it's about — see {@link
 * com.zairo.factory.messaging.MessagingService#sendAsCustomerForBooking} —
 * so a customer messaging from a booking's detail screen gets a thread that
 * shows which booking is being discussed, without a separate per-booking
 * chat concept.
 */
package com.zairo.factory.messaging;
