package com.zairo.factory.vertical.beauty;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** The booking rule: a beauty booking must name a master who offers the requested service. */
@ResponseStatus(HttpStatus.CONFLICT)
public class MasterDoesNotOfferServiceException extends RuntimeException {

    public MasterDoesNotOfferServiceException(String message) {
        super(message);
    }
}
