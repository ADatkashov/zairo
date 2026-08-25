package com.zairo.factory.vertical.auto;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.vertical.auto.VehicleDtos.CreateVehicleRequest;
import com.zairo.factory.vertical.auto.VehicleDtos.VehicleResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Auto — Vehicles")
public class VehicleController {

    private final VehicleService vehicleService;

    public VehicleController(VehicleService vehicleService) {
        this.vehicleService = vehicleService;
    }

    @Operation(summary = "Register a vehicle", description = "Self-service: the caller must be the exact "
            + "user named by `ownerUserId` — can't register a vehicle \"owned\" by someone else.")
    @ApiResponse(responseCode = "201", description = "Vehicle registered")
    @ApiResponse(responseCode = "400", ref = "BadRequest")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "ownerUserId doesn't match the caller's own id.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/vehicles")
    @ResponseStatus(HttpStatus.CREATED)
    public VehicleResponse create(@Valid @RequestBody CreateVehicleRequest request, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(request.ownerUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot register a vehicle for a different "
                    + "user");
        }
        Vehicle vehicle = vehicleService.createVehicle(request.ownerUserId(), request.make(), request.model(),
                request.year(), request.licensePlate());
        return VehicleResponse.from(vehicle);
    }

    @Operation(summary = "Get a vehicle by id")
    @ApiResponse(responseCode = "200", description = "The vehicle")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/vehicles/{vehicleId}")
    public VehicleResponse getById(@Parameter(description = "The vehicle's id.") @PathVariable UUID vehicleId) {
        return VehicleResponse.from(vehicleService.getVehicle(vehicleId));
    }

    @Operation(summary = "List a user's vehicles", description = "Owner-only: the caller must be the exact "
            + "user named by `userId`.")
    @ApiResponse(responseCode = "200", description = "The user's vehicles (empty list if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/vehicles")
    public List<VehicleResponse> listByUser(@Parameter(description = "The user's id.") @PathVariable UUID userId,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot view another user's vehicles");
        }
        return vehicleService.listVehiclesByOwner(userId).stream().map(VehicleResponse::from).toList();
    }

    @Operation(summary = "Delete a vehicle", description = "Owner-only.")
    @ApiResponse(responseCode = "204", description = "Deleted")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/api/v1/vehicles/{vehicleId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@Parameter(description = "The vehicle's id.") @PathVariable UUID vehicleId,
            HttpServletRequest httpRequest) {
        vehicleService.deleteVehicle(vehicleId, CurrentUser.requireUserId(httpRequest));
    }
}
