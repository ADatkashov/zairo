package com.zairo.factory.staff;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** The booking rule: a staff booking must name a staff member who offers the requested service. */
@ResponseStatus(HttpStatus.CONFLICT)
public class StaffDoesNotOfferServiceException extends RuntimeException {

    public StaffDoesNotOfferServiceException(String message) {
        super(message);
    }
}
