package com.zairo.factory.auth;

/**
 * A verified way of proving "this is the same person" — distinct from
 * {@code users.UserRole}, which is about what the user is allowed to do
 * once they're in. One {@link com.zairo.factory.users.User} can have one
 * {@link UserIdentity} per provider (see the {@code
 * uq_user_identity_provider_subject} constraint), so a customer can sign in
 * with Google today and Phone tomorrow and land on the same account.
 */
public enum IdentityProvider {
    GOOGLE,
    FACEBOOK,
    PHONE
}
