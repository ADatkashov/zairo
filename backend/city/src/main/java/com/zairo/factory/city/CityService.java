package com.zairo.factory.city;

import com.zairo.factory.city.CityDtos.CreateCityRequest;
import com.zairo.factory.city.CityDtos.CityDto;
import com.zairo.factory.city.CityDtos.UpdateCityRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CityService {

    private final CityRepository cityRepository;

    public CityService(CityRepository cityRepository) {
        this.cityRepository = cityRepository;
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

        City city = new City(
                request.code(),
                request.name(),
                request.nameKk(),
                request.countryCode(),
                request.timezone() != null ? request.timezone() : "Asia/Almaty",
                request.currency() != null ? request.currency() : "KZT",
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
}
