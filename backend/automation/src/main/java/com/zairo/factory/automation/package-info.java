/**
 * Automation Center: the one settings row a business owns per provider,
 * read by {@code smartfill}/{@code rebookengine}/{@code reactivationengine}
 * to decide whether to run at all for that provider, which audience-rule
 * numbers to use instead of the platform's global defaults, and when it's
 * allowed to actually send a nudge (quiet hours, timezone, a cooldown
 * between offers to the same customer). This module never talks to the
 * engines directly -- they depend on it, never the reverse, same
 * one-directional discipline as every other cross-module reference in this
 * codebase (ADR-0002).
 */
package com.zairo.factory.automation;
