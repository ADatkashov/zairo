package com.zairo.factory.platformadmin;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.security.access.prepost.PreAuthorize;

/** Only {@link PlatformRole#PLATFORM_ADMIN} — the one mutation-capable platform role (401 without a token, 403 otherwise). */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("hasAuthority('PLATFORM_ADMIN')")
public @interface PlatformAdminOnly {
}
