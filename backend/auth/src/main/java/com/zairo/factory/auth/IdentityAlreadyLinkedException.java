package com.zairo.factory.auth;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** This provider identity is already linked — to the caller (no-op) or, more importantly, to someone else. */
@ResponseStatus(HttpStatus.CONFLICT)
public class IdentityAlreadyLinkedException extends RuntimeException {

    public IdentityAlreadyLinkedException(String message) {
        super(message);
    }
}
