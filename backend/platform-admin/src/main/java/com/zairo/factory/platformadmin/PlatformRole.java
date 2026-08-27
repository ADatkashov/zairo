package com.zairo.factory.platformadmin;

/**
 * Two roles, not the full reserve the Control Center brief floated
 * (PLATFORM_MANAGER/ANALYST/FINANCE/OPERATOR). Factory has one real platform
 * job function today (an operator who can moderate the whole platform) and,
 * with this phase, a second (read-only support) — every other candidate role
 * is speculative until an actual person needs permissions that don't fit
 * either of these. Same "don't build ahead of real need" call as
 * {@code SubscriptionPlan}'s two tiers.
 */
public enum PlatformRole {

    /** Full read/write across the Control Center — the only role that can mutate anything. */
    PLATFORM_ADMIN,

    /** Read-only across the whole Control Center — no mutation of any kind. */
    PLATFORM_SUPPORT
}
