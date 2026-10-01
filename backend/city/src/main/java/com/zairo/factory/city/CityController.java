package com.zairo.factory.city;

import com.zairo.factory.city.CityDtos.CityDto;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/cities")
@Tag(name = "Cities")
public class CityController {

    private final CityService cityService;

    public CityController(CityService cityService) {
        this.cityService = cityService;
    }

    @Operation(summary = "Get all cities", description = "Returns a list of all available cities across all countries. "
            + "The frontend app uses this to populate the city selector and fetch cities by country code.")
    @ApiResponse(responseCode = "200", description = "List of all cities", content = @Content(mediaType = "application/json", schema = @Schema(implementation = CityDto[].class)))
    @GetMapping
    public List<CityDto> getAllCities() {
        return cityService.getAllCities();
    }

    @Operation(summary = "Get cities by country code", description = "Returns all cities for a specific country, including inactive ones. "
            + "Used by the platform to retrieve all cities managed under a country.")
    @ApiResponse(responseCode = "200", description = "List of cities for the country")
    @ApiResponse(responseCode = "404", description = "No cities found for the given country code")
    @GetMapping("/country/{countryCode}")
    public List<CityDto> getCitiesByCountryCode(
            @Parameter(description = "Country code (e.g., 'KZ', 'RU')", example = "KZ")
            @PathVariable String countryCode) {
        return cityService.getCitiesByCountryCode(countryCode);
    }

    @Operation(summary = "Get active cities by country code", description = "Returns only active cities for a specific country. "
            + "Used by the frontend app to display available cities to users.")
    @ApiResponse(responseCode = "200", description = "List of active cities for the country")
    @GetMapping("/country/{countryCode}/active")
    public List<CityDto> getActiveCitiesByCountryCode(
            @Parameter(description = "Country code (e.g., 'KZ', 'RU')", example = "KZ")
            @PathVariable String countryCode) {
        return cityService.getActiveCitiesByCountryCode(countryCode);
    }

    @Operation(summary = "Get city by code", description = "Returns a specific city by its unique code. Used to fetch city details for initialization.")
    @ApiResponse(responseCode = "200", description = "City details")
    @ApiResponse(responseCode = "404", description = "City not found")
    @GetMapping("/{code}")
    public CityDto getCityByCode(
            @Parameter(description = "City code (e.g., 'almaty', 'shymkent')", example = "almaty")
            @PathVariable String code) {
        return cityService.getCityByCode(code);
    }
}
