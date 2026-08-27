package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Against a real Postgres (Testcontainers) — public reads against the
 * V25 seed data (Beauty/Auto, Beauty Salon/Auto Service), admin mutation
 * gated by PLATFORM_ADMIN and audit-logged, and the new provider ->
 * businessTypeId resolution at creation time.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class CatalogApiTests {

    private static final String SEEDED_BEAUTY_CATEGORY_ID = "a1111111-1111-4111-8111-111111111111";
    private static final String SEEDED_BEAUTY_SALON_BUSINESS_TYPE_ID = "b1111111-1111-4111-8111-111111111111";

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void publicReadsReturnTheSeededCatalog() {
        ResponseEntity<List> categories = restTemplate.getForEntity("/api/v1/categories", List.class);
        assertThat(categories.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(categories.getBody()).anySatisfy(entry -> {
            Map<?, ?> category = (Map<?, ?>) entry;
            assertThat(category.get("code")).isEqualTo("beauty");
            assertThat(category.get("nameEn")).isEqualTo("Beauty");
        });

        ResponseEntity<List> businessTypes = restTemplate.getForEntity(
                "/api/v1/categories/" + SEEDED_BEAUTY_CATEGORY_ID + "/business-types", List.class);
        assertThat(businessTypes.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(businessTypes.getBody()).anySatisfy(entry -> {
            Map<?, ?> businessType = (Map<?, ?>) entry;
            assertThat(businessType.get("code")).isEqualTo("beauty_salon");
        });
    }

    @Test
    void mutationRequiresPlatformAdminAndIsAuditLogged() {
        var admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "catalog-admin-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_ADMIN);
        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "catalog-support-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        String code = "test_category_" + UUID.randomUUID().toString().replace("-", "");
        Map<String, Object> createRequest = Map.of(
                "code", code, "nameKk", "Тест", "nameRu", "Тест", "nameEn", "Test", "sortOrder", 99);

        // Unauthenticated -> 401.
        ResponseEntity<Map> unauthenticated = restTemplate.postForEntity("/api/v1/platform/categories",
                createRequest, Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // PLATFORM_SUPPORT -> 403.
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/platform/categories", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestPlatformAuth.authHeaders(support.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // PLATFORM_ADMIN -> 201, and it's on the public list.
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/platform/categories", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID newCategoryId = UUID.fromString((String) created.getBody().get("id"));

        ResponseEntity<List> categories = restTemplate.getForEntity("/api/v1/categories", List.class);
        assertThat(categories.getBody()).anySatisfy(entry -> assertThat(((Map<?, ?>) entry).get("code"))
                .isEqualTo(code));

        // Duplicate code -> 409.
        ResponseEntity<Map> duplicate = restTemplate.exchange("/api/v1/platform/categories", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(duplicate.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // Deactivate -> disappears from the public list.
        ResponseEntity<Map> statusUpdate = restTemplate.exchange("/api/v1/platform/categories/" + newCategoryId
                + "/status", HttpMethod.PATCH,
                new HttpEntity<>(Map.of("status", "INACTIVE"), TestPlatformAuth.authHeaders(admin.accessToken())),
                Map.class);
        assertThat(statusUpdate.getStatusCode()).isEqualTo(HttpStatus.OK);
        ResponseEntity<List> afterDeactivate = restTemplate.getForEntity("/api/v1/categories", List.class);
        assertThat(afterDeactivate.getBody())
                .noneSatisfy(entry -> assertThat(((Map<?, ?>) entry).get("code")).isEqualTo(code));

        // Both mutations are on the audit log.
        ResponseEntity<Map> auditLog = restTemplate.exchange("/api/v1/platform/audit-log?size=100", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        List<Map<String, Object>> entries = (List<Map<String, Object>>) auditLog.getBody().get("content");
        assertThat(entries).anySatisfy(entry -> assertThat(entry.get("action")).isEqualTo("CATEGORY_CREATED"));
        assertThat(entries).anySatisfy(entry -> assertThat(entry.get("action")).isEqualTo("CATEGORY_STATUS_CHANGED"));
    }

    @Test
    void newProviderResolvesBusinessTypeIdFromVertical() {
        var owner = TestAuth.registerOwner(restTemplate, "catalog-owner-" + UUID.randomUUID() + "@example.com");
        var request = new CreateProviderRequest(owner.userId(), "Test Salon", "beauty");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().get("businessTypeId")).isEqualTo(SEEDED_BEAUTY_SALON_BUSINESS_TYPE_ID);
    }
}
