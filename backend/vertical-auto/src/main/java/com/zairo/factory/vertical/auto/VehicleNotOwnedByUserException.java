package com.zairo.factory.vertical.auto;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** The booking rule: an auto booking's vehicle must belong to the booking's own user. */
@ResponseStatus(HttpStatus.FORBIDDEN)
public class VehicleNotOwnedByUserException extends RuntimeException {

    public VehicleNotOwnedByUserException(String message) {
        super(message);
    }
}
