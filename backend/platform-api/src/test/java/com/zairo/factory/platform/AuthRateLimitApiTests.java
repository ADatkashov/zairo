package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/** The limit is wired into the real app (the other API tests run with it switched off). */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = "app.rate-limit.enabled=true")
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class AuthRateLimitApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void theEleventhPlatformConsoleLoginInTenMinutesIsRefused() {
        Map<String, String> body = Map.of("email", "nobody@example.com", "password", "wrong-password");
        for (int i = 0; i < 10; i++) {
            assertThat(restTemplate.postForEntity("/api/v1/platform/auth/login", body, Map.class).getStatusCode())
                    .isEqualTo(HttpStatus.UNAUTHORIZED);
        }

        ResponseEntity<Map> limited = restTemplate.postForEntity("/api/v1/platform/auth/login", body, Map.class);

        assertThat(limited.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(limited.getHeaders().getFirst("Retry-After")).isNotNull();
    }
}
