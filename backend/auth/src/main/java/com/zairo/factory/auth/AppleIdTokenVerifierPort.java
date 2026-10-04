package com.zairo.factory.auth;

import java.util.Optional;

/**
 * Port to "Sign in with Apple" identity-token verification — same split as
 * {@link GoogleIdTokenVerifierPort}: one real adapter, a port so
 * IdentityService's tests can use a fake. An empty result covers every kind
 * of rejection; callers must not try to tell them apart.
 */
public interface AppleIdTokenVerifierPort {

    Optional<VerifiedIdentity> verify(String identityToken);

    /**
     * {@code subject} is Apple's stable, app-team-scoped user id. {@code email}
     * may be a private-relay address ({@code ...@privaterelay.appleid.com})
     * or null (Apple only includes it the first time); Apple's relay emails
     * are real, working addresses, so {@code emailVerified} is trusted when
     * Apple says so.
     */
    record VerifiedIdentity(String subject, String email, boolean emailVerified) {
    }
}
