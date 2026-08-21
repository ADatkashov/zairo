/**
 * Country configuration — Phase A of the platform's internationalization
 * architecture (see the "Factory Country Architecture" design document).
 * One {@link com.zairo.factory.country.Country} row per market; adding a
 * market is a new row plus its localization/adapter resources, never a
 * schema or code change here.
 *
 * <p>This module is foundational: everything else depends on it, it
 * depends on nothing else. {@link com.zairo.factory.country.CountryContext}
 * is the cross-module entry point for "which country is this request for"
 * — the same shape as {@code auth}'s {@code CurrentUser} reading what
 * {@code JwtAuthFilter} populated, here {@link com.zairo.factory.country.CountryResolutionFilter}
 * populates the request attribute {@code CountryContext} reads.
 *
 * <p>Deliberately not yet in this module: feature flags, tax/legal
 * configuration, address/phone format rules, and payment/delivery/auth
 * provider selection. Those are real fields in the target config model,
 * but nothing in the codebase consumes them yet — they're added in the
 * phase that actually needs them, not spun up as unused columns now.
 */
package com.zairo.factory.country;
