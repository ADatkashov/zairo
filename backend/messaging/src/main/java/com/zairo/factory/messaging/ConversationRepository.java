package com.zairo.factory.messaging;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {

    Optional<Conversation> findByCustomerIdAndProviderId(UUID customerId, UUID providerId);

    List<Conversation> findByCustomerIdOrderByLastMessageAtDesc(UUID customerId);

    List<Conversation> findByProviderIdOrderByLastMessageAtDesc(UUID providerId);
}
