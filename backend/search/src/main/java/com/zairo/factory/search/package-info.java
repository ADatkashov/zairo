/**
 * Search and ranking over Providers/Services. MVP ranking is deterministic
 * (rating, distance, price, availability) — no ML until it's proven necessary.
 *
 * <p>Home's discovery feed is built here too, from the same read-only, no-new-table shape: "book again"
 * ({@link com.zairo.factory.search.BookAgainService}), "popular services"
 * ({@link com.zairo.factory.search.PopularServicesService}, real bookings of the last 90 days) and "recommended for
 * you" ({@link com.zairo.factory.search.RecommendationsService}, the categories a customer books in). The ranking
 * rules of the last two live in pure static classes ({@code PopularServicesRanker}, {@code RecommendationsRanker}) so
 * they are unit-tested without a database. See docs/home-discovery.md.
 */
package com.zairo.factory.search;
