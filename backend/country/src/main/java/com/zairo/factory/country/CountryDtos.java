package com.zairo.factory.country;

import java.util.List;

public class CountryDtos {

    private CountryDtos() {
    }

    public record CountryResponse(String code, String name, String defaultLanguage, List<String> supportedLanguages,
            String currency, String timezone, String numberFormat, String dateFormat, String status) {

        static CountryResponse from(Country country) {
            return new CountryResponse(country.getCode(), country.getName(), country.getDefaultLanguage(),
                    country.getSupportedLanguages(), country.getCurrency(), country.getTimezone(),
                    country.getNumberFormat(), country.getDateFormat(), country.getStatus().name());
        }
    }
}
