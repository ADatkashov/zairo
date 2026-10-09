package com.zairo.factory.subscriptions;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubscriptionPaymentMethodRepository extends JpaRepository<SubscriptionPaymentMethod, UUID> {
}
