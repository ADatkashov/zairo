package com.zairo.factory.vertical.auto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/** Self-service vehicle CRUD — a vehicle belongs to a Core {@code User}, not a {@code Provider}. */
@Service
public class VehicleService {

    private final VehicleRepository vehicleRepository;

    public VehicleService(VehicleRepository vehicleRepository) {
        this.vehicleRepository = vehicleRepository;
    }

    /** Self-service: the caller must be the exact user named by {@code ownerUserId} — checked by the controller. */
    @Transactional
    public Vehicle createVehicle(UUID ownerUserId, String make, String model, int year, String licensePlate) {
        Vehicle vehicle = new Vehicle(UUID.randomUUID(), ownerUserId, make, model, year, licensePlate,
                Instant.now());
        return vehicleRepository.save(vehicle);
    }

    public Vehicle getVehicle(UUID vehicleId) {
        return vehicleRepository.findById(vehicleId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Vehicle not found: "
                        + vehicleId));
    }

    public List<Vehicle> listVehiclesByOwner(UUID ownerUserId) {
        return vehicleRepository.findByOwnerUserId(ownerUserId);
    }

    /** Owner-only — checked by the controller, same as the getVehicle 404-first-then-403 order elsewhere. */
    @Transactional
    public void deleteVehicle(UUID vehicleId, UUID requestingUserId) {
        Vehicle vehicle = getVehicle(vehicleId);
        if (!vehicle.getOwnerUserId().equals(requestingUserId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot delete another user's vehicle");
        }
        vehicleRepository.delete(vehicle);
    }
}
