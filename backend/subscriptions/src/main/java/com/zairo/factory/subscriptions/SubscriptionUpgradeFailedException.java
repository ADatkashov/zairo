package com.zairo.factory.subscriptions;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.PAYMENT_REQUIRED)
public class SubscriptionUpgradeFailedException extends RuntimeException {

    public SubscriptionUpgradeFailedException(String message) {
        super(message);
    }
}
