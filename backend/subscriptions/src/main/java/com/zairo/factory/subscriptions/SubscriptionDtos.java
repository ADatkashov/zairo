package com.zairo.factory.subscriptions;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;
import java.util.UUID;

public final class SubscriptionDtos {

    private SubscriptionDtos() {
    }

    public record SubscriptionResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID ownerUserId,
            SubscriptionPlan plan,
            SubscriptionStatus status,
            @Schema(description = "This plan's limits, so a client never has to hardcode them.")
            PlanLimits limits,
            Instant currentPeriodStart,
            Instant currentPeriodEnd,
            @Schema(description = "Only set while status is PAST_DUE.")
            Instant gracePeriodEndsAt,
            @Schema(description = "True if a self-service downgrade to FREE is scheduled for currentPeriodEnd.")
            boolean cancelAtPeriodEnd,
            @Schema(description = "Set only right after an upgrade under a real (non-mock) payment provider: "
                    + "redirect the customer here to complete the charge. The plan/status fields above are still "
                    + "the pre-upgrade values in that case — the subscription becomes PRO only once the provider's "
                    + "webhook confirms the payment, not when this response is returned.")
            String checkoutUrl) {

        static SubscriptionResponse from(Subscription subscription) {
            return from(subscription, null);
        }

        static SubscriptionResponse from(Subscription subscription, String checkoutUrl) {
            SubscriptionPlan plan = subscription.getPlan();
            return new SubscriptionResponse(subscription.getId(), subscription.getOwnerUserId(), plan,
                    subscription.getStatus(), PlanLimits.from(plan), subscription.getCurrentPeriodStart(),
                    subscription.getCurrentPeriodEnd(), subscription.getGracePeriodEndsAt(),
                    subscription.isCancelAtPeriodEnd(), checkoutUrl);
        }
    }

    public record PlanLimits(int maxProviders, int maxStaffPerProvider,
            @Schema(description = "Integer.MAX_VALUE means unlimited.") int maxBookingsPerMonth,
            boolean recurringScheduleAllowed) {

        static PlanLimits from(SubscriptionPlan plan) {
            return new PlanLimits(plan.maxProviders, plan.maxStaffPerProvider, plan.maxBookingsPerMonth,
                    plan.recurringScheduleAllowed);
        }
    }
}
