package com.zairo.factory.platformadmin;

/**
 * Three roles, not the full reserve the Control Center brief floated
 * (PLATFORM_MANAGER/ANALYST/FINANCE/OPERATOR). Factory has one real platform
 * job function today (an operator who can moderate the whole platform), a
 * second (read-only support), and a third added once business moderation
 * (approve/suspend a provider) moved into the Control Center instead of
 * requiring the separate legacy {@code users.UserRole.ADMIN} login or direct
 * database access — every other candidate role is speculative until an
 * actual person needs permissions that don't fit one of these. Same "don't
 * build ahead of real need" call as {@code SubscriptionPlan}'s two tiers.
 */
public enum PlatformRole {

    /** Full read/write across the Control Center — the only role that can manage taxonomy or other admins. */
    PLATFORM_ADMIN,

    /** Read-only across the whole Control Center — no mutation of any kind. */
    PLATFORM_SUPPORT,

    /** Can moderate businesses (approve/suspend/reinstate a provider) but nothing else that mutates. */
    PLATFORM_MODERATOR
}
