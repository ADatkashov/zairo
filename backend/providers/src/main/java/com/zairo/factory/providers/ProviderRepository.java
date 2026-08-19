package com.zairo.factory.providers;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProviderRepository extends JpaRepository<Provider, UUID> {

    List<Provider> findByVertical(String vertical);
}
