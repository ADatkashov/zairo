/**
 * The {@link com.zairo.factory.paymentprovider.PaymentProvider} port and its
 * only implementation so far ({@link com.zairo.factory.paymentprovider.MockPaymentProvider}).
 * Extracted from {@code payments} once {@code subscriptions} needed the same
 * port for recurring charges — see this module's build.gradle.kts for why
 * that would otherwise have created a Gradle module cycle.
 */
package com.zairo.factory.paymentprovider;
