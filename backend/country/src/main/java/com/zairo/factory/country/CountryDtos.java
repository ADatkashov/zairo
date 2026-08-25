package com.zairo.factory.country;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public class CountryDtos {

    private CountryDtos() {
    }

    public record CountryResponse(
            @Schema(description = "ISO 3166-1 alpha-2.", example = "KZ") String code,
            @Schema(example = "Kazakhstan") String name,
            @Schema(example = "kk") String defaultLanguage,
            @Schema(example = "[\"kk\", \"ru\", \"en\"]") List<String> supportedLanguages,
            @Schema(description = "ISO 4217.", example = "KZT") String currency,
            @Schema(description = "IANA zone id.", example = "Asia/Almaty") String timezone,
            @Schema(example = "# ###,##") String numberFormat,
            @Schema(example = "dd.MM.yyyy") String dateFormat,
            @Schema(description = "DRAFT (not resolvable/visible to end users yet), ACTIVE, or SUSPENDED — "
                    + "only ACTIVE countries are returned by GET /countries.",
                    allowableValues = {"DRAFT", "ACTIVE", "SUSPENDED"}, example = "ACTIVE")
            String status) {

        static CountryResponse from(Country country) {
            return new CountryResponse(country.getCode(), country.getName(), country.getDefaultLanguage(),
                    country.getSupportedLanguages(), country.getCurrency(), country.getTimezone(),
                    country.getNumberFormat(), country.getDateFormat(), country.getStatus().name());
        }
    }
}
