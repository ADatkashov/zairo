package com.zairo.factory.platformadmin;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.security.access.prepost.PreAuthorize;

/** {@link PlatformRole#PLATFORM_ADMIN} or {@link PlatformRole#PLATFORM_MODERATOR} — may moderate businesses. */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@PreAuthorize("hasAnyAuthority('PLATFORM_ADMIN', 'PLATFORM_MODERATOR')")
public @interface PlatformModerationCapable {
}
