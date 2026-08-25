package com.zairo.factory.country;

import com.zairo.factory.country.CountryDtos.CountryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/** No authentication is required by either endpoint here. */
@RestController
@Tag(name = "Country")
public class CountryController {

    private final CountryService countryService;

    public CountryController(CountryService countryService) {
        this.countryService = countryService;
    }

    @Operation(summary = "List active countries", description = "Only ACTIVE countries — a DRAFT one isn't "
            + "ready to be shown or resolved as anyone's default yet.")
    @ApiResponse(responseCode = "200", description = "Active countries")
    @GetMapping("/api/v1/countries")
    public List<CountryResponse> listActive() {
        return countryService.listActive().stream().map(CountryResponse::from).toList();
    }

    @Operation(summary = "Get a country by code", description = "By code regardless of status — unlike the "
            + "list endpoint, this also returns a DRAFT country (an admin tool needs to fetch one while "
            + "building it out).")
    @ApiResponse(responseCode = "200", description = "The country")
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @GetMapping("/api/v1/countries/{code}")
    public CountryResponse getByCode(
            @Parameter(description = "ISO 3166-1 alpha-2, case-insensitive.", example = "KZ")
            @PathVariable String code) {
        return CountryResponse.from(countryService.getByCode(code));
    }
}
