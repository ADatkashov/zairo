package com.zairo.factory.providers;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.security.access.prepost.PreAuthorize;

/**
 * The caller must own the provider named by this method's {@code providerId} parameter:
 * 401 without a customer/business token, 404 if the provider does not exist, 403 if it
 * belongs to someone else — the same answers {@link ProviderOwnership#requireOwner} always gave.
 * Enforced by method security before the method body runs.
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("@providerOwnership.requireCurrentOwner(#providerId)")
public @interface OwnsProvider {
}
