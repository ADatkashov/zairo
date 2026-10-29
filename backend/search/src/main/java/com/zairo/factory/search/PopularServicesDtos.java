package com.zairo.factory.search;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

public final class PopularServicesDtos {

    private PopularServicesDtos() {
    }

    public record PopularService(
            @Schema(description = "The service as the first (most booked) business spelled it.",
                    example = "Classic Manicure") String title,
            @Schema(description = "Bookings that were made and kept (CONFIRMED or COMPLETED) in the window, "
                    + "summed over every business offering a service of this name.", example = "42") long bookings,
            @Schema(description = "How many active businesses offer it.", example = "7") int providerCount,
            @Schema(description = "The lowest price among them.", example = "25.00") BigDecimal minPrice,
            @Schema(example = "KZT") String currency,
            @Schema(description = "The category (vertical) of the business behind the most booked offering, for an icon.",
                    example = "beauty") String vertical) {
    }
}
