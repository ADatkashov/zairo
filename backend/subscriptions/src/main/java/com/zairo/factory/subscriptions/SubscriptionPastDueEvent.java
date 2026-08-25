package com.zairo.factory.subscriptions;

import java.util.UUID;

/** Published when a subscription is actually downgraded to FREE — either its grace period expired, or a self-service downgrade reached its period end. */
public record SubscriptionPastDueEvent(UUID subscriptionId, UUID ownerUserId) {
}
