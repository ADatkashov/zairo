package com.zairo.factory.vertical.cleaning;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** The booking rule: a cleaning booking must name a cleaner who offers the requested service. */
@ResponseStatus(HttpStatus.CONFLICT)
public class CleanerDoesNotOfferServiceException extends RuntimeException {

    public CleanerDoesNotOfferServiceException(String message) {
        super(message);
    }
}
