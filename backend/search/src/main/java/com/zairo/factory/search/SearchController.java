package com.zairo.factory.search;

import com.zairo.factory.search.SearchDtos.ProviderSearchResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.math.BigDecimal;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Search")
public class SearchController {

    private final SearchService searchService;

    public SearchController(SearchService searchService) {
        this.searchService = searchService;
    }

    @Operation(summary = "Search providers", description = """
            Customer-facing discovery — always filters to ACTIVE providers only (unlike GET /providers, \
            which returns every moderation status). Every filter is optional and combines with AND; \
            omit all of them to get every ACTIVE provider. No authentication required.

            **Workflow**: `Search -> Get provider details -> Create booking` — the usual customer entry \
            point.""")
    @ApiResponse(responseCode = "200", description = "Matching providers, empty list if none match")
    @GetMapping("/api/v1/search/providers")
    public List<ProviderSearchResult> search(
            @Parameter(description = "Exact match on vertical, e.g. \"beauty\".", example = "beauty")
            @RequestParam(required = false) String vertical,
            @Parameter(description = "Free-text match against provider/service names.", example = "manicure")
            @RequestParam(required = false) String q,
            @Parameter(description = "Caller's latitude — required together with `lng` to get `distanceKm` "
                    + "in results or to use `maxDistanceKm`.", example = "43.238293")
            @RequestParam(required = false) Double lat,
            @Parameter(description = "Caller's longitude — see `lat`.", example = "76.945465")
            @RequestParam(required = false) Double lng,
            @Parameter(description = "Only providers with at least one service priced at or above this.",
                    example = "10.00") @RequestParam(required = false) BigDecimal minPrice,
            @Parameter(description = "Only providers with at least one service priced at or below this.",
                    example = "50.00") @RequestParam(required = false) BigDecimal maxPrice,
            @Parameter(description = "Requires `lat`/`lng`. Only providers within this many kilometers.",
                    example = "5.0") @RequestParam(required = false) Double maxDistanceKm,
            @Parameter(description = "Only providers with an average rating at or above this.", example = "4.0")
            @RequestParam(required = false) Double minRating,
            @Parameter(description = "Only providers with at least one OPEN availability slot right now.")
            @RequestParam(required = false, defaultValue = "false") boolean availableOnly,
            @Parameter(description = "Ranking order — defaults to RECOMMENDED (a blended score) if omitted.")
            @RequestParam(required = false) SearchSort sort) {
        return searchService.search(vertical, q, lat, lng, minPrice, maxPrice, maxDistanceKm, minRating,
                availableOnly, sort);
    }
}
