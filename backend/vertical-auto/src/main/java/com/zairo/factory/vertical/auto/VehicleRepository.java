package com.zairo.factory.vertical.auto;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VehicleRepository extends JpaRepository<Vehicle, UUID> {

    /** Account deletion. */
    void deleteByOwnerUserId(UUID ownerUserId);

    List<Vehicle> findByOwnerUserId(UUID ownerUserId);
}
