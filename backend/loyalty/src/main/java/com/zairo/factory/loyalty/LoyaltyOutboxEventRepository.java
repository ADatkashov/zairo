package com.zairo.factory.loyalty;

import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

interface LoyaltyOutboxEventRepository extends JpaRepository<LoyaltyOutboxEvent, UUID> {

    List<LoyaltyOutboxEvent> findByStatusOrderByCreatedAtAsc(LoyaltyOutboxEventStatus status, Pageable pageable);
}
