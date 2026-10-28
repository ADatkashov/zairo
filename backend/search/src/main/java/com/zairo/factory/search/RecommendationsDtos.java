package com.zairo.factory.search;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.UUID;

public final class RecommendationsDtos {

    private RecommendationsDtos() {
    }

    /** One business worth showing this customer, in the order it should be shown. */
    public record RecommendedProvider(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(description = "The category (vertical) of their own history that this one matches.",
                    example = "beauty") String vertical) {
    }
}
