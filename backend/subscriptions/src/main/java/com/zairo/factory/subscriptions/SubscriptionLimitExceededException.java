package com.zairo.factory.subscriptions;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** 402, not 403/409 — this isn't an authorization or state conflict, it's "pay to unlock this." */
@ResponseStatus(HttpStatus.PAYMENT_REQUIRED)
public class SubscriptionLimitExceededException extends RuntimeException {

    public SubscriptionLimitExceededException(String message) {
        super(message);
    }
}
