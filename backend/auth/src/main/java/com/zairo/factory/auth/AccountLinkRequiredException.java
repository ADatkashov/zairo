package com.zairo.factory.auth;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * A Google/Facebook sign-in carries a provider-verified email that already
 * belongs to an account whose email was never verified (registered by
 * typing it in with a password). Joining them silently would let whoever
 * pre-registered that email inherit the real owner's login, so the caller
 * must first prove they own the existing account — see
 * {@code POST /auth/identities/link-with-password}. The message always
 * starts with {@link #CODE} so clients can tell this 409 apart from other
 * conflicts.
 */
@ResponseStatus(HttpStatus.CONFLICT)
public class AccountLinkRequiredException extends RuntimeException {

    public static final String CODE = "ACCOUNT_LINK_REQUIRED";

    public AccountLinkRequiredException() {
        super(CODE + ": an account with this email already exists - confirm its password to connect it");
    }
}
