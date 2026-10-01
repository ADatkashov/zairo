package com.zairo.factory.city;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CityRepository extends JpaRepository<City, UUID> {
    Optional<City> findByCode(String code);

    List<City> findByCountryCode(String countryCode);

    List<City> findByCountryCodeAndActiveTrue(String countryCode);
}
