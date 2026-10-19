package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Prometheus metrics are an operator opt-in: by default only health/info are
 * exposed, because the app has no Spring Security and a public /actuator/prometheus
 * would leak internals.
 */
class MetricsEndpointApiTests {

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    @AutoConfigureTestRestTemplate
    @Import(TestcontainersConfiguration.class)
    class ByDefault {

        @Autowired
        private TestRestTemplate restTemplate;

        @Test
        void prometheusIsNotExposed() {
            ResponseEntity<String> response = restTemplate.getForEntity("/actuator/prometheus", String.class);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        }

        @Test
        void healthStaysAvailable() {
            ResponseEntity<String> response = restTemplate.getForEntity("/actuator/health", String.class);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        }
    }

    @Nested
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
            properties = "MANAGEMENT_ENDPOINTS_EXPOSE=health,info,prometheus")
    @AutoConfigureTestRestTemplate
    @Import(TestcontainersConfiguration.class)
    class WhenTheOperatorEnablesIt {

        @Autowired
        private TestRestTemplate restTemplate;

        @Test
        void prometheusServesJvmAndHttpMetrics() {
            restTemplate.getForEntity("/actuator/health", String.class);

            ResponseEntity<String> response = restTemplate.getForEntity("/actuator/prometheus", String.class);

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(response.getBody()).contains("jvm_memory_used_bytes");
        }
    }
}
