package com.zairo.factory.loyalty;

import java.time.LocalDate;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoyaltyGreetingRepository extends JpaRepository<LoyaltyGreeting, UUID> {

    boolean existsByProviderIdAndUserIdAndGreetingDate(UUID providerId, UUID userId, LocalDate greetingDate);
}
