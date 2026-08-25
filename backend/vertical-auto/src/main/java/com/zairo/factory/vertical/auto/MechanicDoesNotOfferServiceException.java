package com.zairo.factory.vertical.auto;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** The booking rule: an auto booking must name a mechanic who offers the requested service. */
@ResponseStatus(HttpStatus.CONFLICT)
public class MechanicDoesNotOfferServiceException extends RuntimeException {

    public MechanicDoesNotOfferServiceException(String message) {
        super(message);
    }
}
