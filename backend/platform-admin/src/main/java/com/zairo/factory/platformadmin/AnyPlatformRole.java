package com.zairo.factory.platformadmin;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.security.access.prepost.PreAuthorize;

/** Any platform role (admin, moderator or read-only support) — read access to the console. */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("hasAnyAuthority('PLATFORM_ADMIN', 'PLATFORM_MODERATOR', 'PLATFORM_SUPPORT')")
public @interface AnyPlatformRole {
}
