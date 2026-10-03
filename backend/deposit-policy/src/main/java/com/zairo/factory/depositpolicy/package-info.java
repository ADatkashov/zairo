/**
 * Deposit policy: a provider's configured deposit requirement
 * ({@link com.zairo.factory.depositpolicy.PaymentSettings}) and the pure
 * calculation of how much a deposit comes to
 * ({@link com.zairo.factory.depositpolicy.DepositCalculator}). Split out of
 * {@code payments} so both {@code booking} (captures the policy on each
 * Booking at creation time) and {@code payments} (exposes it over HTTP, and
 * enforces it when charging) can depend on it without a cycle — payments
 * already depends on booking, so booking depending back on payments would
 * loop.
 */
package com.zairo.factory.depositpolicy;
