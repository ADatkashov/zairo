package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.PaymentProviderName;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentWebhookEventRepository extends JpaRepository<PaymentWebhookEvent, UUID> {

    Optional<PaymentWebhookEvent> findByProviderAndEventId(PaymentProviderName provider, String eventId);
}
