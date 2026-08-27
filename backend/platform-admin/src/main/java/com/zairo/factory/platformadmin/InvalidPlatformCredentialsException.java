package com.zairo.factory.platformadmin;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.UNAUTHORIZED)
public class InvalidPlatformCredentialsException extends RuntimeException {

    public InvalidPlatformCredentialsException(String message) {
        super(message);
    }
}
