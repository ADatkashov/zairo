package com.zairo.factory.subscriptions;

import org.springframework.data.jpa.repository.JpaRepository;

public interface SubscriptionPriceRepository extends JpaRepository<SubscriptionPriceRow, SubscriptionPlan> {
}
