/**
 * Basic 1:1 text chat between a customer and a business — one {@link
 * com.zairo.factory.messaging.Conversation} per (customer, provider) pair,
 * persisting across multiple bookings. No attachments, no group threads, no
 * read receipts — all deliberately out of scope (see
 * docs/PRODUCT_PRODUCTION_ROADMAP.md section 14/"Can Wait"). Poll-based
 * (plain REST {@code GET}), not real-time — no WebSocket infrastructure
 * exists in this project yet, and polling is the simplest thing that
 * actually closes the gap.
 */
package com.zairo.factory.messaging;
