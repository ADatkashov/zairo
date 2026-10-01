package com.zairo.factory.auth;

import java.util.Optional;

/**
 * Port to Google ID token verification — kept separate from {@link
 * GoogleIdTokenVerifierAdapter} (the real implementation, backed by
 * Google's own {@code google-api-client} library) purely so
 * {@link IdentityService} can be unit-tested against a fake, the same way
 * {@code payments.PaymentProvider} is. There is exactly one real
 * implementation; this isn't a hint that a second production provider is
 * coming.
 */
public interface GoogleIdTokenVerifierPort {

    /**
     * Empty if the token fails verification for <b>any</b> reason (bad
     * signature, wrong audience, wrong issuer, expired, malformed) — see
     * GoogleIdTokenVerifierAdapter for exactly which checks that covers.
     * Never throws for a bad token; only for the verifier itself being
     * unable to reach Google's key-discovery endpoint. A caller must not
     * try to distinguish rejection reasons from an empty result — see
     * InvalidProviderCredentialException's doc comment.
     */
    Optional<VerifiedIdentity> verify(String idToken);

    record VerifiedIdentity(String subject, String email, boolean emailVerified, String displayName) {
    }
}
