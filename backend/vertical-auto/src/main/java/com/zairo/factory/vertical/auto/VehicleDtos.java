package com.zairo.factory.vertical.auto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class VehicleDtos {

    private VehicleDtos() {
    }

    // Bounds mirror auto_vehicle's actual columns (V21 migration) — make/
    // model varchar(100) not null, license_plate varchar(20) not null.
    public record CreateVehicleRequest(
            @NotNull @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID ownerUserId,
            @NotBlank @Size(max = 100) @Schema(example = "Toyota") String make,
            @NotBlank @Size(max = 100) @Schema(example = "Camry") String model,
            @Schema(example = "2019") int year,
            @NotBlank @Size(max = 20) @Schema(example = "777 ABC 02") String licensePlate) {
    }

    public record VehicleResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID ownerUserId,
            @Schema(example = "Toyota") String make,
            @Schema(example = "Camry") String model,
            @Schema(example = "2019") int year,
            @Schema(example = "777 ABC 02") String licensePlate,
            Instant createdAt) {
        static VehicleResponse from(Vehicle vehicle) {
            return new VehicleResponse(vehicle.getId(), vehicle.getOwnerUserId(), vehicle.getMake(),
                    vehicle.getModel(), vehicle.getYear(), vehicle.getLicensePlate(), vehicle.getCreatedAt());
        }
    }
}
