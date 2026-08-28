package com.zairo.factory.paymentprovider;

/**
 * Thrown by {@link PaymentProvider#chargeRecurring} when an implementation
 * genuinely cannot perform the operation yet — see ADR-0006's Open
 * Questions #1: Freedom Pay's real request shape for charging a saved
 * recurring profile isn't confirmed by public documentation. Callers
 * (specifically {@code subscriptions.SubscriptionRenewalService}) already
 * catch {@code RuntimeException} from a charge attempt and route it through
 * the existing PAST_DUE/grace-period path — this exception deliberately
 * reuses that path rather than inventing new error handling for "we don't
 * know how to do this yet" versus "the provider declined the charge": both
 * genuinely mean "this subscription didn't get charged today."
 */
public class UnsupportedRecurringChargeException extends RuntimeException {

    public UnsupportedRecurringChargeException(String message) {
        super(message);
    }
}
