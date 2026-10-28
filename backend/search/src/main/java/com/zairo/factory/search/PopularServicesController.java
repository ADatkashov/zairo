package com.zairo.factory.search;

import com.zairo.factory.search.PopularServicesDtos.PopularService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Search")
public class PopularServicesController {

    private final PopularServicesService popularServicesService;

    public PopularServicesController(PopularServicesService popularServicesService) {
        this.popularServicesService = popularServicesService;
    }

    @Operation(summary = "Most booked services", description = """
            Home's "Popular services": the services customers actually booked most in the last 90 days \
            (CONFIRMED or COMPLETED bookings), grouped by service name across businesses, most booked first. \
            Only active offerings of ACTIVE businesses are counted. Empty on a platform that has no bookings \
            yet -- clients then fall back to what search results offer. No authentication required.""")
    @ApiResponse(responseCode = "200", description = "Popular services, most booked first (empty if none yet)")
    @GetMapping("/api/v1/search/popular-services")
    public List<PopularService> popularServices(
            @Parameter(description = "A city code (GET /cities): only bookings made in that city.", example = "almaty")
            @RequestParam(required = false) String city,
            @Parameter(description = "How many to return, 1-20.", example = "8")
            @RequestParam(required = false) Integer limit) {
        return popularServicesService.popular(city, limit);
    }
}
