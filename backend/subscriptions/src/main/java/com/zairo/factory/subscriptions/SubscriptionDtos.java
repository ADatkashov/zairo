package com.zairo.factory.subscriptions;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
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
            String checkoutUrl,
            @Schema(description = "What PRO costs per month, so a client never hardcodes the price.", example = "29.00")
            BigDecimal proMonthlyPrice,
            @Schema(description = "ISO 4217 currency PRO is charged in.", example = "USD")
            String currency) {

        static SubscriptionResponse from(Subscription subscription, String currency) {
            return from(subscription, null, currency);
        }

        static SubscriptionResponse from(Subscription subscription, String checkoutUrl, String currency) {
            SubscriptionPlan plan = subscription.getPlan();
            return new SubscriptionResponse(subscription.getId(), subscription.getOwnerUserId(), plan,
                    subscription.getStatus(), PlanLimits.from(plan), subscription.getCurrentPeriodStart(),
                    subscription.getCurrentPeriodEnd(), subscription.getGracePeriodEndsAt(),
                    subscription.isCancelAtPeriodEnd(), checkoutUrl, SubscriptionPlan.PRO.monthlyPrice, currency);
        }
    }

    @Schema(description = "One billing-period charge attempt — the Billing screen's invoice history "
            + "(v2 design audit).")
    public record SubscriptionChargeResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            BigDecimal amount,
            String currency,
            SubscriptionChargeStatus status,
            Instant createdAt) {

        static SubscriptionChargeResponse from(SubscriptionCharge charge) {
            return new SubscriptionChargeResponse(charge.getId(), charge.getAmount(), charge.getCurrency(),
                    charge.getStatus(), charge.getCreatedAt());
        }
    }

    @Schema(description = "The card the subscription renews with. Display data only — never a full card number.")
    public record PaymentMethodResponse(
            @Schema(description = "False when no card is stored; the other card fields are then null.")
            boolean saved,
            @Schema(example = "VISA", nullable = true) String brand,
            @Schema(example = "4242", nullable = true) String last4,
            Instant addedAt,
            @Schema(description = "True when the renewal will really be charged by itself: the provider can charge a "
                    + "stored card, one is stored, the plan is PRO and no downgrade is scheduled. False means the owner "
                    + "pays each renewal in checkout.")
            boolean autoRenew) {
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
