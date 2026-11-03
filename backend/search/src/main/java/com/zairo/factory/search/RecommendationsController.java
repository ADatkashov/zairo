package com.zairo.factory.search;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.search.RecommendationsDtos.RecommendedProvider;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@Tag(name = "Search")
public class RecommendationsController {

    private final RecommendationsService recommendationsService;

    public RecommendationsController(RecommendationsService recommendationsService) {
        this.recommendationsService = recommendationsService;
    }

    @Operation(summary = "Businesses recommended for this customer", description = """
            Self-service only: the caller must be the exact user named by `userId`. Learned from the \
            customer's own kept bookings (CONFIRMED or COMPLETED): businesses of the categories they book in, \
            more of the category they book in most, best-rated first, never one they have already been to \
            (those are in `book-again`). Only ACTIVE businesses; with `city`, that city's plus those with no \
            city set. Ids in display order -- the client already holds the business details from search. \
            Empty when the customer has no booking history yet.""")
    @ApiResponse(responseCode = "200", description = "Recommended businesses in display order (empty if none)")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", ref = "Forbidden")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/users/{userId}/recommendations")
    public List<RecommendedProvider> recommendations(
            @Parameter(description = "The user's id.") @PathVariable UUID userId,
            @Parameter(description = "A city code (GET /cities).", example = "almaty")
            @RequestParam(required = false) String city,
            @Parameter(description = "How many to return, 1-30.", example = "10")
            @RequestParam(required = false) Integer limit) {
        UUID callerId = CurrentUser.requireUserId();
        if (!callerId.equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot view another user's recommendations");
        }
        return recommendationsService.forUser(userId, city, limit);
    }
}
