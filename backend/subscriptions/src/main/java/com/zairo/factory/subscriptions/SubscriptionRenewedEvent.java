package com.zairo.factory.subscriptions;

import java.util.UUID;

/** Published after a subscription's monthly renewal charge succeeds — see ADR-0002 (in-process domain events). */
public record SubscriptionRenewedEvent(UUID subscriptionId, UUID ownerUserId, SubscriptionPlan plan) {
}
