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
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

/**
 * A client that uses the wrong HTTP method or Content-Type must get a 405 / 415
 * with the standard error body — not the opaque 500 these used to fall into.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class HttpErrorStatusApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void unsupportedMethodIs405WithAnAllowHeader() {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auth/login", HttpMethod.PUT,
                new HttpEntity<>(Map.of()), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.METHOD_NOT_ALLOWED);
        assertThat(response.getHeaders().getAllow()).contains(HttpMethod.POST);
        assertThat(response.getBody()).containsEntry("status", 405);
    }

    @Test
    void unsupportedContentTypeIs415() {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.TEXT_PLAIN);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auth/login", HttpMethod.POST,
                new HttpEntity<>("x", headers), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNSUPPORTED_MEDIA_TYPE);
        assertThat(response.getBody()).containsEntry("status", 415);
    }
}
