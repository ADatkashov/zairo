package com.zairo.factory.country;

import com.zairo.factory.country.CountryDtos.CountryResponse;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CountryController {

    private final CountryService countryService;

    public CountryController(CountryService countryService) {
        this.countryService = countryService;
    }

    @GetMapping("/api/v1/countries")
    public List<CountryResponse> listActive() {
        return countryService.listActive().stream().map(CountryResponse::from).toList();
    }

    @GetMapping("/api/v1/countries/{code}")
    public CountryResponse getByCode(@PathVariable String code) {
        return CountryResponse.from(countryService.getByCode(code));
    }
}
