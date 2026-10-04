package com.zairo.factory.auth;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** The platform-wide daily SMS cap is reached — a circuit breaker against SMS-pumping fraud, not a per-user limit. */
@ResponseStatus(HttpStatus.SERVICE_UNAVAILABLE)
public class OtpTemporarilyUnavailableException extends RuntimeException {

    public OtpTemporarilyUnavailableException(String message) {
        super(message);
    }
}
