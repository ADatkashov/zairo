package com.zairo.factory.auth;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * The Google ID token / Facebook access token failed provider verification
 * — bad signature, wrong audience/issuer, expired, or the provider
 * rejected it outright. Deliberately one generic message for every one of
 * those reasons (see GoogleIdTokenVerifierAdapter/FacebookGraphIdentityVerifier):
 * telling a caller *which* check failed would help someone probing for a
 * forgeable edge case more than it helps a legitimate client, which only
 * needs to know "try signing in again."
 */
@ResponseStatus(HttpStatus.UNAUTHORIZED)
public class InvalidProviderCredentialException extends RuntimeException {

    public InvalidProviderCredentialException(String message) {
        super(message);
    }
}
