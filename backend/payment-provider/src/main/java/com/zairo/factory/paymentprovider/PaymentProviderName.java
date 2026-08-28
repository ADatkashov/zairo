package com.zairo.factory.paymentprovider;

/**
 * Which {@link PaymentProvider} implementation actually handled a given
 * {@code Payment}/{@code SubscriptionCharge} — stored on the row itself
 * (see ADR-0006's Data Model section) so historical charges keep an honest
 * record even after the active provider changes via {@code payment.provider}
 * config. Not a place to special-case provider behavior outside this
 * module — callers should never switch on this enum, only read/store it.
 */
public enum PaymentProviderName {
    MOCK,
    FREEDOMPAY
}
