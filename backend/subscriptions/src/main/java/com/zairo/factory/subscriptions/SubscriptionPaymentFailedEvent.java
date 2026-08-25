package com.zairo.factory.subscriptions;

import java.time.Instant;
import java.util.UUID;

/** Published when a renewal charge fails — the subscription enters PAST_DUE with a grace period until {@code gracePeriodEndsAt}. */
public record SubscriptionPaymentFailedEvent(UUID subscriptionId, UUID ownerUserId, Instant gracePeriodEndsAt) {
}
