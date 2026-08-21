package com.zairo.factory.booking;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.BAD_REQUEST)
public class InvalidRecurringScheduleException extends RuntimeException {

    public InvalidRecurringScheduleException(String message) {
        super(message);
    }
}
