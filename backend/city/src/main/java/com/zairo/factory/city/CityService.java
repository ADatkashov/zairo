package com.zairo.factory.city;

import com.zairo.factory.city.CityDtos.CreateCityRequest;
import com.zairo.factory.city.CityDtos.CityDto;
import com.zairo.factory.city.CityDtos.UpdateCityRequest;
import com.zairo.factory.country.Country;
import com.zairo.factory.country.CountryService;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CityService {

    private final CityRepository cityRepository;
    private final UserRepository userRepository;
    private final CountryService countryService;

    public CityService(CityRepository cityRepository, UserRepository userRepository,
            CountryService countryService) {
        this.cityRepository = cityRepository;
        this.userRepository = userRepository;
        this.countryService = countryService;
    }

    public List<CityDto> getAllCities() {
        return cityRepository.findAll().stream()
                .map(CityDtos::toDto)
                .toList();
    }

    public List<CityDto> getCitiesByCountryCode(String countryCode) {
        return cityRepository.findByCountryCode(countryCode).stream()
                .map(CityDtos::toDto)
                .toList();
    }

    public List<CityDto> getActiveCitiesByCountryCode(String countryCode) {
        return cityRepository.findByCountryCodeAndActiveTrue(countryCode).stream()
                .map(CityDtos::toDto)
                .toList();
    }

    public CityDto getCityByCode(String code) {
        City city = cityRepository.findByCode(code)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "City not found: " + code));
        return CityDtos.toDto(city);
    }

    public CityDto createCity(CreateCityRequest request) {
        if (cityRepository.findByCode(request.code()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "City code already exists: " + request.code());
        }

        // A new city inherits its country's timezone and currency unless the
        // request names its own — never a fixed market's values, so adding a
        // city in another country (e.g. Uzbekistan) gets that country's currency.
        Country country = countryService.getByCode(request.countryCode());
        City city = new City(
                request.code(),
                request.name(),
                request.nameKk(),
                request.countryCode(),
                request.timezone() != null ? request.timezone() : country.getTimezone(),
                request.currency() != null ? request.currency() : country.getCurrency(),
                request.latitude(),
                request.longitude(),
                request.defaultSearchRadiusKm(),
                true);

        City saved = cityRepository.save(city);
        return CityDtos.toDto(saved);
    }

    public CityDto updateCity(String code, UpdateCityRequest request) {
        City city = cityRepository.findByCode(code)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "City not found: " + code));

        city.update(
                request.name(),
                request.nameKk(),
                request.timezone(),
                request.currency(),
                request.latitude(),
                request.longitude(),
                request.defaultSearchRadiusKm(),
                request.active());

        City saved = cityRepository.save(city);
        return CityDtos.toDto(saved);
    }

    public void deleteCity(String code) {
        City city = cityRepository.findByCode(code)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "City not found: " + code));
        cityRepository.delete(city);
    }

    public CityDto setUserCurrentCity(UUID userId, String cityCode) {
        City city = cityRepository.findByCode(cityCode)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "City not found: " + cityCode));

        if (!city.getActive()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Cannot select inactive city. Please contact support.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        user.setCurrentCityCode(cityCode);
        userRepository.save(user);

        return CityDtos.toDto(city);
    }

    public CityDto getUserCurrentCity(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        if (user.getCurrentCityCode() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "User has not selected a city yet");
        }

        return getCityByCode(user.getCurrentCityCode());
    }

    public CityDto getNearestCity(double latitude, double longitude) {
        List<City> activeCities = cityRepository.findByActiveTrue();
        if (activeCities.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No active cities available");
        }

        City nearest = activeCities.stream()
                .min((c1, c2) -> Double.compare(
                        calculateDistance(latitude, longitude, c1.getLatitude().doubleValue(), c1.getLongitude().doubleValue()),
                        calculateDistance(latitude, longitude, c2.getLatitude().doubleValue(), c2.getLongitude().doubleValue())))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No cities found"));

        return CityDtos.toDto(nearest);
    }

    private double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371;
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}
