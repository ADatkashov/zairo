package com.zairo.factory.auth;

import java.util.Optional;

/**
 * Port to Facebook access-token verification — see
 * GoogleIdTokenVerifierPort's doc comment for why this is a separate
 * interface from its real implementation ({@link
 * FacebookGraphIdentityVerifier}).
 */
public interface FacebookIdentityVerifierPort {

    /**
     * Empty if the token fails verification for any reason: it isn't a
     * valid Facebook user access token, it wasn't issued to *this* app (the
     * {@code debug_token} check — see FacebookGraphIdentityVerifier), or
     * Facebook's Graph API rejected/couldn't answer the follow-up profile
     * lookup. Same "don't distinguish why" contract as
     * GoogleIdTokenVerifierPort.verify.
     */
    Optional<VerifiedIdentity> verify(String userAccessToken);

    /** email/emailVerified are null/false when the user didn't grant the email permission. */
    record VerifiedIdentity(String subject, String email, boolean emailVerified, String displayName) {
    }
}
