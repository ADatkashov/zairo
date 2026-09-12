package com.zairo.factory.revenueengine;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.util.Map;

public final class RevenueEngineDtos {

    private RevenueEngineDtos() {
    }

    /**
     * "Revenue Recovered by ZAIRO" — the top-line number the product's
     * whole value proposition rests on (see revenue-engine's package-info),
     * plus the per-{@link ActionType} breakdown a future dashboard would
     * show under it.
     */
    public record RevenueSummaryResponse(
            @Schema(example = "347500.00") BigDecimal totalRecovered,
            @Schema(example = "KZT") String currency,
            @Schema(description = "How many decisions the engine has executed for this provider.") long decisionsExecuted,
            @Schema(description = "Of those, how many actually recovered revenue.") long decisionsRecovered,
            Map<ActionType, BigDecimal> recoveredByActionType) {
    }
}
