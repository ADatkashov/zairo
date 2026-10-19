package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetailsService;

/** What Spring Security adds around the API: headers, stateless, error format, CORS, no default user. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class SpringSecurityApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserDetailsService userDetailsService;

    @Test
    void publicResponsesCarrySecurityHeadersAndNoSessionCookie() {
        ResponseEntity<String> response = restTemplate.getForEntity("/api/v1/categories", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        HttpHeaders headers = response.getHeaders();
        assertThat(headers.getFirst("X-Content-Type-Options")).isEqualTo("nosniff");
        assertThat(headers.getFirst("X-Frame-Options")).isEqualTo("DENY");
        assertThat(headers.getFirst("Referrer-Policy")).isEqualTo("no-referrer");
        assertThat(headers.get(HttpHeaders.SET_COOKIE)).isNull();
    }

    @Test
    void anAnonymousCallToAProtectedEndpointIsA401WithTheNormalErrorBody() {
        ResponseEntity<Map> response = restTemplate.getForEntity(
                "/api/v1/users/00000000-0000-0000-0000-000000000001/bookings", Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody()).containsEntry("status", 401).containsKeys("timestamp", "error", "message", "path");
        assertThat(response.getHeaders().getFirst(HttpHeaders.WWW_AUTHENTICATE)).isNull();
    }

    @Test
    void aBrowserPreflightFromALocalOriginStillWorks() {
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.ORIGIN, "http://localhost:8101");
        headers.set(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST");
        headers.set(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "authorization,content-type");

        ResponseEntity<String> response = restTemplate.exchange("/api/v1/bookings", HttpMethod.OPTIONS,
                new HttpEntity<>(headers), String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getAccessControlAllowOrigin()).isEqualTo("http://localhost:8101");
    }

    @Test
    void aForeignOriginIsNotAllowedByCors() {
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.ORIGIN, "https://evil.example");
        headers.set(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST");

        ResponseEntity<String> response = restTemplate.exchange("/api/v1/bookings", HttpMethod.OPTIONS,
                new HttpEntity<>(headers), String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void thereIsNoDefaultUserToLogInAs() {
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> userDetailsService.loadUserByUsername("user"))
                .isInstanceOf(org.springframework.security.core.userdetails.UsernameNotFoundException.class);
    }

    @Test
    void httpBasicIsNotAcceptedAsACredential() {
        HttpHeaders headers = new HttpHeaders();
        headers.setBasicAuth("admin", "admin");

        ResponseEntity<String> response = restTemplate.exchange(
                "/api/v1/users/00000000-0000-0000-0000-000000000001/bookings", HttpMethod.GET,
                new HttpEntity<>(headers), String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
