package com.zairo.factory.services;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.security.access.prepost.PreAuthorize;

/**
 * The caller must own the business that offers the service named by this method's {@code id} parameter
 * (403 if not). A service that does not exist passes the check — the method itself answers 404 (or, for
 * the idempotent deactivate, 204) exactly as before.
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("@serviceAccess.requireCurrentOwner(#id)")
public @interface OwnsService {
}
