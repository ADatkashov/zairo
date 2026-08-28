package com.zairo.factory.paymentprovider.freedompay;

/**
 * Wraps a Freedom Pay HTTP-level failure (network timeout, connection
 * error, non-2xx response, or a 2xx response whose body isn't the XML shape
 * expected) into one domain-level type — callers (see {@code
 * FreedomPayProvider}) catch this alongside any other {@code
 * RuntimeException} the way {@code PaymentsService}/{@code
 * SubscriptionRenewalService} already handle a provider failure: mark the
 * payment/charge FAILED, never let a transport error masquerade as success.
 */
public class FreedomPayHttpException extends RuntimeException {

    public FreedomPayHttpException(String message) {
        super(message);
    }

    public FreedomPayHttpException(String message, Throwable cause) {
        super(message, cause);
    }
}
