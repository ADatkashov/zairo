package com.zairo.factory.search;

import com.zairo.factory.search.SearchDtos.ProviderSearchResult;
import com.zairo.factory.search.SearchDtos.SearchResults;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
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

            **Paging**: the response body stays a bare JSON array (`page`/`size` default to 0/50, `size` \
            capped at 100) — existing callers that never pass these keep getting exactly what they get \
            today at current data volumes. The total match count (not just this page) is on the \
            `X-Total-Count` response header, not in the body, so the array shape never changes.

            **Workflow**: `Search -> Get provider details -> Create booking` — the usual customer entry \
            point.""")
    @ApiResponse(responseCode = "200", description = "Matching providers for this page, empty array if none match")
    @GetMapping("/api/v1/search/providers")
    public ResponseEntity<List<ProviderSearchResult>> search(
            @Parameter(description = "Exact match on vertical, e.g. \"beauty\".", example = "beauty")
            @RequestParam(required = false) String vertical,
            @Parameter(description = "Filter to providers of this catalog.BusinessType — a more specific "
                    + "alternative to `vertical` (see GET /categories/{id}/business-types). Combines with "
                    + "`vertical` if both are given.")
            @RequestParam(required = false) UUID businessTypeId,
            @Parameter(description = "Filter to providers with an active offering linked to this exact "
                    + "catalog.CatalogService — \"who actually offers Manicure\" (see PATCH "
                    + "/services/{id}/catalog-link).")
            @RequestParam(required = false) UUID catalogServiceId,
            @Parameter(description = "Free-text match against provider/service names — also matches a "
                    + "service's linked master-catalog name in any of its languages, see PATCH "
                    + "/services/{id}/catalog-link.", example = "manicure")
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
            @RequestParam(required = false) SearchSort sort,
            @Parameter(description = "Zero-based page index.") @RequestParam(required = false, defaultValue = "0")
            int page,
            @Parameter(description = "Page size, capped at 100.") @RequestParam(required = false,
                    defaultValue = "50") int size) {
        SearchResults results = searchService.search(vertical, businessTypeId, catalogServiceId, q, lat, lng,
                minPrice, maxPrice, maxDistanceKm, minRating, availableOnly, sort, page, size);
        return ResponseEntity.ok().header("X-Total-Count", String.valueOf(results.totalCount()))
                .body(results.content());
    }
}
