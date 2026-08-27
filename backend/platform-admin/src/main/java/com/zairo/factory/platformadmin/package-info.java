/**
 * Platform staff identity, authorization, and audit log — the internal
 * Factory Control Center's own bounded context. Deliberately has no Gradle
 * dependency on {@code auth} or {@code users}: a customer or business-owner
 * account can never be mistaken for platform staff here, because there is
 * no code path in this module that even knows those types exist.
 */
package com.zairo.factory.platformadmin;
