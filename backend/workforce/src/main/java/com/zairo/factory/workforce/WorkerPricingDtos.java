package com.zairo.factory.workforce;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.UUID;

/** Per-worker prices ("this master charges more for this service"). */
public final class WorkerPricingDtos {

    private WorkerPricingDtos() {
    }

    public record WorkerPriceResponse(UUID serviceId, BigDecimal price) {
    }

    public record ServiceWorkerPriceResponse(UUID workerId, BigDecimal price) {
    }

    public record SetWorkerPriceRequest(
            @NotNull UUID serviceId,
            @DecimalMin("0") @Schema(description = "The worker's price; omit (null) to go back to the service's own price.")
            BigDecimal price) {
    }
}
