package com.zairo.factory.booking;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.security.access.prepost.PreAuthorize;

/**
 * The caller must own the business of the availability slot named by this method's {@code id} parameter
 * (403 if not). A slot that does not exist passes the check — the method itself answers 404 as before.
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("@slotAccess.requireCurrentOwner(#id)")
public @interface OwnsSlot {
}
