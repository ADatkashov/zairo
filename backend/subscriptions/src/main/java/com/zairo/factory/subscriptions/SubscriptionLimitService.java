package com.zairo.factory.subscriptions;

import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * The one thing other bounded-context modules (providers, vertical-beauty,
 * vertical-auto, booking) call — each already knows its own current count
 * (query already run for its own listing/validation purposes), so this
 * takes that count as a plain {@code int} rather than reaching into those
 * modules' own repositories itself. Keeps {@code subscriptions} dependency-
 * free of providers/booking/vertical-* (see build.gradle.kts), avoiding a
 * cycle with the modules that depend on it.
 */
@Service
public class SubscriptionLimitService {

    private final SubscriptionService subscriptionService;

    public SubscriptionLimitService(SubscriptionService subscriptionService) {
        this.subscriptionService = subscriptionService;
    }

    public void checkCanCreateProvider(UUID ownerUserId, int currentProviderCount) {
        SubscriptionPlan plan = subscriptionService.getOrCreate(ownerUserId).getPlan();
        if (currentProviderCount >= plan.maxProviders) {
            throw new SubscriptionLimitExceededException("Your " + plan + " plan allows at most "
                    + plan.maxProviders + " business(es) — upgrade to add more.");
        }
    }

    public void checkCanAddStaff(UUID ownerUserId, int currentStaffCount) {
        SubscriptionPlan plan = subscriptionService.getOrCreate(ownerUserId).getPlan();
        if (currentStaffCount >= plan.maxStaffPerProvider) {
            throw new SubscriptionLimitExceededException("Your " + plan + " plan allows at most "
                    + plan.maxStaffPerProvider + " staff member(s) per business — upgrade to add more.");
        }
    }

    public void checkCanCreateBooking(UUID ownerUserId, int currentMonthBookingCount) {
        SubscriptionPlan plan = subscriptionService.getOrCreate(ownerUserId).getPlan();
        if (currentMonthBookingCount >= plan.maxBookingsPerMonth) {
            throw new SubscriptionLimitExceededException("Your " + plan + " plan allows at most "
                    + plan.maxBookingsPerMonth + " booking(s) per month — upgrade for unlimited bookings.");
        }
    }

    public void checkRecurringScheduleAllowed(UUID ownerUserId) {
        SubscriptionPlan plan = subscriptionService.getOrCreate(ownerUserId).getPlan();
        if (!plan.recurringScheduleAllowed) {
            throw new SubscriptionLimitExceededException(
                    "Recurring schedule generation requires the PRO plan — upgrade to use it.");
        }
    }
}
