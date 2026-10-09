package com.zairo.factory.subscriptions;

/** Why a {@link SubscriptionCharge} exists: the first PRO payment, or a later billing period's renewal. */
public enum SubscriptionChargePurpose {
    UPGRADE, RENEWAL
}
