/**
 * Promo banners for the customer app's Home screen, each with an optional
 * video link that opens in an in-app player. Banners are not videos hosted by
 * us: {@code videoUrl} is an https link to an external host, and the image
 * (cover) goes through the existing image storage.
 *
 * <p>Step 1 is platform-curated: a platform admin or moderator creates a
 * banner and moves it through {@link com.zairo.factory.ads.AdStatus}. The
 * {@code providerId} column is already here for step 2 (a business buys a
 * placement, pays, and waits in {@code PENDING_REVIEW} for moderation), so
 * that step adds endpoints and payment, not a new table.
 *
 * <p>Public endpoint:
 * <ul>
 *   <li>{@code GET /api/v1/ads/banners?city=} — live banners for a city (plus those for every city)</li>
 * </ul>
 * Platform endpoints ({@code /api/v1/platform/ads}): list, create, update,
 * set status, delete. Reads: any platform role; writes: PLATFORM_ADMIN or
 * PLATFORM_MODERATOR. Every write is audit-logged.
 */
package com.zairo.factory.ads;
