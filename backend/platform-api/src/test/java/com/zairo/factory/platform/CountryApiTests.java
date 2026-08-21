package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Against a real Postgres (Testcontainers): the seeded KZ row (see
 * V15__create_country_table.sql) is readable through both endpoints, and
 * an unknown code 404s.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class CountryApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void listsOnlyActiveCountriesIncludingTheSeededKazakhstanRow() {
        ResponseEntity<List> response = restTemplate.getForEntity("/api/v1/countries", List.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<Map<String, Object>> countries = response.getBody();
        Map<String, Object> kz = countries.stream()
                .filter(c -> "KZ".equals(c.get("code")))
                .findFirst()
                .orElseThrow(() -> new AssertionError("KZ not present in /api/v1/countries"));

        assertThat(kz.get("name")).isEqualTo("Kazakhstan");
        assertThat(kz.get("defaultLanguage")).isEqualTo("kk");
        assertThat(kz.get("supportedLanguages")).isEqualTo(List.of("kk", "ru", "en"));
        assertThat(kz.get("currency")).isEqualTo("KZT");
        assertThat(kz.get("timezone")).isEqualTo("Asia/Almaty");
        assertThat(kz.get("status")).isEqualTo("ACTIVE");
    }

    @Test
    void getByCodeIsCaseInsensitive() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/api/v1/countries/kz", Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("code")).isEqualTo("KZ");
    }

    @Test
    void getByCodeReturns404ForAnUnknownCountry() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/api/v1/countries/zz", Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
