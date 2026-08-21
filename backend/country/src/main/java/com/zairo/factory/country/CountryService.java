package com.zairo.factory.country;

import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CountryService {

    private final CountryRepository countryRepository;

    public CountryService(CountryRepository countryRepository) {
        this.countryRepository = countryRepository;
    }

    /** Public-facing list — a DRAFT country isn't ready to be shown or resolved as anyone's default yet. */
    public List<Country> listActive() {
        return countryRepository.findByStatus(CountryStatus.ACTIVE);
    }

    /** By code regardless of status — an admin tool needs to fetch a DRAFT country while building it out. */
    public Country getByCode(String code) {
        return countryRepository.findById(code.toUpperCase())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Country not found: " + code));
    }
}
