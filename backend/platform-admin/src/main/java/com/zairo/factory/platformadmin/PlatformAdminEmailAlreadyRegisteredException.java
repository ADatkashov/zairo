package com.zairo.factory.platformadmin;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.CONFLICT)
public class PlatformAdminEmailAlreadyRegisteredException extends RuntimeException {

    public PlatformAdminEmailAlreadyRegisteredException(String message) {
        super(message);
    }
}
