package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

/**
 * Against a real Postgres (Testcontainers) — storage itself doesn't touch
 * Postgres, but this suite reuses the same platform-api context as every
 * other *ApiTests class (see the test-isolation note in SearchApiTests).
 * Requires MinIO from infrastructure/docker-compose.yml to be running
 * locally; unlike Postgres, MinIO isn't Testcontainerized here (no
 * dev-vs-test split for object storage yet — same scope cut noted for
 * every other piece of dev-only infra in this project).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class StorageApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void uploadsAFileAndDownloadsTheSameBytesBack() {
        byte[] content = "hello from a test photo".getBytes(StandardCharsets.UTF_8);
        ByteArrayResource resource = new ByteArrayResource(content) {
            @Override
            public String getFilename() {
                return "test.txt";
            }
        };

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", resource);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        HttpEntity<MultiValueMap<String, Object>> request = new HttpEntity<>(body, headers);

        ResponseEntity<Map> uploadResponse = restTemplate.postForEntity("/api/v1/uploads", request, Map.class);
        assertThat(uploadResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String key = (String) uploadResponse.getBody().get("key");
        String url = (String) uploadResponse.getBody().get("url");
        assertThat(key).endsWith(".txt");
        assertThat(url).endsWith("/api/v1/uploads/" + key);

        ResponseEntity<byte[]> downloadResponse = restTemplate.getForEntity("/api/v1/uploads/" + key, byte[].class);
        assertThat(downloadResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(downloadResponse.getBody()).isEqualTo(content);
    }

    @Test
    void downloadingAnUnknownKeyReturns404() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/api/v1/uploads/does-not-exist.txt", Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
