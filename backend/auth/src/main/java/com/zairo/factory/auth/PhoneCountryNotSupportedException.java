package com.zairo.factory.auth;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** A valid phone number, but from a country SMS codes aren't sent to (see app.otp.allowed-countries). */
@ResponseStatus(HttpStatus.BAD_REQUEST)
public class PhoneCountryNotSupportedException extends RuntimeException {

    public PhoneCountryNotSupportedException(String message) {
        super(message);
    }
}
