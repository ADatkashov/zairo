package com.zairo.factory.city;

import com.zairo.factory.city.CityDtos.CreateCityRequest;
import com.zairo.factory.city.CityDtos.CityDto;
import com.zairo.factory.city.CityDtos.UpdateCityRequest;
import com.zairo.factory.platformadmin.PlatformCurrentAdmin;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Platform Admin-only endpoints for managing cities. Only PLATFORM_ADMIN role can create, update, or delete cities.
 * These endpoints are NOT for public use and require a valid platform access token.
 */
@RestController
@RequestMapping("/api/v1/platform/cities")
@Tag(name = "Platform Admin - Cities")
public class CityAdminController {

    private final CityService cityService;

    public CityAdminController(CityService cityService) {
        this.cityService = cityService;
    }

    @Operation(summary = "Create a new city", description = "PLATFORM_ADMIN-only. Creates a new city for a country. "
            + "The city code must be unique; if it already exists, a 409 Conflict is returned. "
            + "Cities are always created as active by default.")
    @ApiResponse(responseCode = "201", description = "City created successfully")
    @ApiResponse(responseCode = "400", description = "Invalid request data", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", description = "Missing or invalid platform access token", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", description = "Authenticated but not PLATFORM_ADMIN role", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "409", description = "City code already exists", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CityDto createCity(
            @Valid @RequestBody CreateCityRequest request,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        return cityService.createCity(request);
    }

    @Operation(summary = "Update a city", description = "PLATFORM_ADMIN-only. Updates an existing city's details. "
            + "The city code cannot be changed (it's the natural identifier).")
    @ApiResponse(responseCode = "200", description = "City updated successfully")
    @ApiResponse(responseCode = "400", description = "Invalid request data", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "401", description = "Missing or invalid platform access token", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", description = "Authenticated but not PLATFORM_ADMIN role", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", description = "City not found")
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/{code}")
    public CityDto updateCity(
            @Parameter(description = "City code (e.g., 'almaty')", example = "almaty")
            @PathVariable String code,
            @Valid @RequestBody UpdateCityRequest request,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        return cityService.updateCity(code, request);
    }

    @Operation(summary = "Delete a city", description = "PLATFORM_ADMIN-only. Deletes a city entirely. "
            + "This is a destructive operation and cannot be undone. Use the active flag to soft-delete instead.")
    @ApiResponse(responseCode = "204", description = "City deleted successfully")
    @ApiResponse(responseCode = "401", description = "Missing or invalid platform access token", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "403", description = "Authenticated but not PLATFORM_ADMIN role", content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", description = "City not found")
    @SecurityRequirement(name = "bearerAuth")
    @DeleteMapping("/{code}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCity(
            @Parameter(description = "City code (e.g., 'almaty')", example = "almaty")
            @PathVariable String code,
            HttpServletRequest httpRequest) {
        PlatformCurrentAdmin.requireAdminId(httpRequest);
        PlatformCurrentAdmin.requirePlatformAdmin(httpRequest);
        cityService.deleteCity(code);
    }
}
