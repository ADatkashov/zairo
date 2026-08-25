package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Iterator;
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
 * A regression guard for the OpenAPI/Swagger documentation itself (see
 * OpenApiConfig, GlobalExceptionHandler, and every controller's
 * {@code @Operation} annotations) — not a test of any business behavior.
 * The one rule this actively enforces: every operation must have a
 * {@code summary}, so a newly-added endpoint that forgets to document
 * itself fails the build instead of silently shipping undocumented.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class OpenApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void apiDocsIsValidOpenApiJsonWithEveryOperationDocumented() throws Exception {
        ResponseEntity<String> response = restTemplate.getForEntity("/v3/api-docs", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);

        JsonNode root = objectMapper.readTree(response.getBody());
        assertThat(root.path("openapi").asText()).startsWith("3.");
        assertThat(root.path("info").path("title").asText()).isEqualTo("Factory API");

        JsonNode paths = root.path("paths");
        assertThat(paths.size()).isGreaterThan(30);

        int operationCount = 0;
        Iterator<Map.Entry<String, JsonNode>> pathEntries = paths.fields();
        while (pathEntries.hasNext()) {
            Map.Entry<String, JsonNode> pathEntry = pathEntries.next();
            Iterator<Map.Entry<String, JsonNode>> methodEntries = pathEntry.getValue().fields();
            while (methodEntries.hasNext()) {
                Map.Entry<String, JsonNode> methodEntry = methodEntries.next();
                JsonNode operation = methodEntry.getValue();
                assertThat(operation.path("summary").asText())
                        .as("summary for %s %s", methodEntry.getKey(), pathEntry.getKey())
                        .isNotBlank();
                operationCount++;
            }
        }
        assertThat(operationCount).isGreaterThan(50);

        assertThat(root.path("components").path("securitySchemes").has("bearerAuth")).isTrue();
    }

    @Test
    void apiDocsYamlIsAlsoServed() {
        ResponseEntity<String> response = restTemplate.getForEntity("/v3/api-docs.yaml", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("openapi:");
    }

    @Test
    void swaggerUiIsServed() {
        ResponseEntity<String> response = restTemplate.getForEntity("/swagger-ui/index.html", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("swagger-ui");
    }
}
