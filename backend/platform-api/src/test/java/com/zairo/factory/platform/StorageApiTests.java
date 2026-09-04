package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

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
 *
 * These fixtures are the minimum bytes that satisfy DetectedImageType's
 * signature checks, not full valid images — the module only ever inspects
 * the leading bytes, so that's all a test needs to exercise it honestly.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class StorageApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    private static final byte[] JPEG_BYTES = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0, 'J', 'F',
            'I', 'F', 0, 1};
    private static final byte[] PNG_BYTES = {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n', 0, 0, 0, 0};
    private static final byte[] WEBP_BYTES = {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'E', 'B', 'P', 'V', 'P', '8', ' '};
    private static final byte[] HTML_BYTES = "<html><body><script>alert(document.cookie)</script></body></html>"
            .getBytes(java.nio.charset.StandardCharsets.UTF_8);
    private static final byte[] SVG_BYTES = ("<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\">"
            + "<script>alert(document.cookie)</script></svg>").getBytes(java.nio.charset.StandardCharsets.UTF_8);
    private static final byte[] EXECUTABLE_BYTES = {'M', 'Z', (byte) 0x90, 0, 3, 0, 0, 0, 4, 0, 0, 0};

    @Test
    void uploadsAValidJpegAndDownloadsTheSameBytesBackWithATrustedContentType() {
        UploadResult result = upload("photo.jpg", JPEG_BYTES, MediaType.IMAGE_JPEG);
        assertThat(result.response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(result.key).endsWith(".jpg");

        ResponseEntity<byte[]> download = restTemplate.getForEntity("/api/v1/uploads/" + result.key, byte[].class);
        assertThat(download.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(download.getBody()).isEqualTo(JPEG_BYTES);
        assertThat(download.getHeaders().getContentType()).isEqualTo(MediaType.IMAGE_JPEG);
    }

    @Test
    void uploadsAValidPngAndItSucceeds() {
        UploadResult result = upload("photo.png", PNG_BYTES, MediaType.IMAGE_PNG);
        assertThat(result.response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(result.key).endsWith(".png");
    }

    @Test
    void uploadsAValidWebpAndItSucceeds() {
        UploadResult result = upload("photo.webp", WEBP_BYTES, MediaType.valueOf("image/webp"));
        assertThat(result.response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(result.key).endsWith(".webp");
    }

    @Test
    void rejectsAnHtmlFileEvenWhenDisguisedWithAnImageExtensionAndContentType() {
        UploadResult result = upload("photo.jpg", HTML_BYTES, MediaType.IMAGE_JPEG);
        assertThat(result.response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void rejectsAnSvgFile() {
        UploadResult result = upload("photo.svg", SVG_BYTES, MediaType.valueOf("image/svg+xml"));
        assertThat(result.response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void rejectsAFileWhoseDeclaredContentTypeDoesNotMatchItsActualBytes() {
        // Client claims this is a JPEG; the bytes are actually HTML. Detection is byte-based, so the
        // claimed Content-Type is irrelevant either way — this must still be rejected.
        UploadResult result = upload("innocent.jpg", HTML_BYTES, MediaType.IMAGE_JPEG);
        assertThat(result.response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void rejectsAnArbitraryExecutableFile() {
        UploadResult result = upload("update.exe", EXECUTABLE_BYTES, MediaType.APPLICATION_OCTET_STREAM);
        assertThat(result.response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void downloadingAnUnknownKeyReturns404() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/api/v1/uploads/does-not-exist.txt", Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    private record UploadResult(ResponseEntity<Map> response, String key) {
    }

    private UploadResult upload(String filename, byte[] content, MediaType declaredContentType) {
        ByteArrayResource resource = new ByteArrayResource(content) {
            @Override
            public String getFilename() {
                return filename;
            }
        };

        TestAuth.Registered uploader = TestAuth.registerCustomer(restTemplate,
                "storage-uploader-" + java.util.UUID.randomUUID() + "@example.com");

        HttpHeaders partHeaders = new HttpHeaders();
        partHeaders.setContentType(declaredContentType);
        HttpEntity<ByteArrayResource> filePart = new HttpEntity<>(resource, partHeaders);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", filePart);
        HttpHeaders headers = TestAuth.authHeaders(uploader.accessToken());
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        HttpEntity<MultiValueMap<String, Object>> request = new HttpEntity<>(body, headers);

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/uploads", request, Map.class);
        String key = response.getStatusCode() == HttpStatus.CREATED ? (String) response.getBody().get("key") : null;
        return new UploadResult(response, key);
    }
}
