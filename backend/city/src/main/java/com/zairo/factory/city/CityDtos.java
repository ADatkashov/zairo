package com.zairo.factory.city;

import com.fasterxml.jackson.annotation.JsonProperty;

public class CityDtos {

    public record CityDto(
            String code,
            String name,
            @JsonProperty("name_kk")
            String nameKk,
            @JsonProperty("country_code")
            String countryCode,
            String timezone,
            String currency,
            Double latitude,
            Double longitude,
            @JsonProperty("default_search_radius_km")
            Integer defaultSearchRadiusKm,
            Boolean active) {
    }

    public record CreateCityRequest(
            String code,
            String name,
            @JsonProperty("name_kk")
            String nameKk,
            @JsonProperty("country_code")
            String countryCode,
            String timezone,
            String currency,
            Double latitude,
            Double longitude,
            @JsonProperty("default_search_radius_km")
            Integer defaultSearchRadiusKm) {
    }

    public record UpdateCityRequest(
            String name,
            @JsonProperty("name_kk")
            String nameKk,
            String timezone,
            String currency,
            Double latitude,
            Double longitude,
            @JsonProperty("default_search_radius_km")
            Integer defaultSearchRadiusKm,
            Boolean active) {
    }

    public static CityDto toDto(City city) {
        return new CityDto(
                city.getCode(),
                city.getName(),
                city.getNameKk(),
                city.getCountryCode(),
                city.getTimezone(),
                city.getCurrency(),
                city.getLatitude(),
                city.getLongitude(),
                city.getDefaultSearchRadiusKm(),
                city.getActive());
    }
}
