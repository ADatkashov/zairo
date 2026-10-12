package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.users.UserRepository;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
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

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

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

    /**
     * The product rule this guards: {@code Category.status} is a
     * customer-catalog-visibility switch for launching a vertical, never a
     * cascade onto {@code Provider.status}. A vertical can be pre-provisioned
     * with real businesses in the database while still INACTIVE (not yet
     * announced to customers); those businesses keep whatever status an
     * ADMIN already gave them, and stay fully discoverable by anyone who
     * already knows how to ask for that vertical (direct search by
     * `vertical`, a favorite, a bookmarked profile link) the entire time —
     * only the customer-facing "pick a category" surfaces (GET /categories
     * and everything built on it) hide it. Flipping the category to ACTIVE
     * later is purely additive: it makes the category itself pickable, it
     * does not touch a single Provider row.
     */
    @Test
    void deactivatingACategoryNeverChangesAnExistingBusinesssStatusOrDiscoverability() {
        var platformAdmin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "catalog-launch-admin-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_ADMIN);
        String code = "medicine_" + UUID.randomUUID().toString().replace("-", "");
        Map<String, Object> createCategoryRequest = Map.of(
                "code", code, "nameKk", "Медицина", "nameRu", "Медицина", "nameEn", "Medicine", "sortOrder", 50);
        ResponseEntity<Map> createdCategory = restTemplate.exchange("/api/v1/platform/categories", HttpMethod.POST,
                new HttpEntity<>(createCategoryRequest, TestPlatformAuth.authHeaders(platformAdmin.accessToken())),
                Map.class);
        assertThat(createdCategory.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID categoryId = UUID.fromString((String) createdCategory.getBody().get("id"));

        // Not launched yet -- the vertical starts INACTIVE, same as
        // Medicine/Dentistry/Auto/Cleaning would while Beauty alone is live.
        ResponseEntity<Map> deactivated = restTemplate.exchange(
                "/api/v1/platform/categories/" + categoryId + "/status", HttpMethod.PATCH,
                new HttpEntity<>(Map.of("status", "INACTIVE"),
                        TestPlatformAuth.authHeaders(platformAdmin.accessToken())),
                Map.class);
        assertThat(deactivated.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<List> categoriesWhileInactive = restTemplate.getForEntity("/api/v1/categories", List.class);
        assertThat(categoriesWhileInactive.getBody())
                .noneSatisfy(entry -> assertThat(((Map<?, ?>) entry).get("code")).isEqualTo(code));

        // A business can still be onboarded under this not-yet-launched
        // vertical, and an ADMIN can still approve it to ACTIVE -- exactly
        // the pre-provisioning step 2 of the launch scenario describes.
        var owner = TestAuth.registerOwner(restTemplate, "medicine-owner-" + UUID.randomUUID() + "@example.com");
        var createProviderRequest = new CreateProviderRequest(owner.userId(), "Test Clinic", code);
        ResponseEntity<Map> createdProvider = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(createProviderRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(createdProvider.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString((String) createdProvider.getBody().get("id"));

        Registered legacyAdmin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "medicine-approver-" + UUID.randomUUID() + "@example.com");
        ResponseEntity<Map> approved = restTemplate.exchange("/api/v1/providers/" + providerId + "/status",
                HttpMethod.PATCH,
                new HttpEntity<>(new UpdateProviderStatusRequest(ProviderStatus.ACTIVE),
                        TestAuth.authHeaders(legacyAdmin.accessToken())),
                Map.class);
        assertThat(approved.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(approved.getBody().get("status")).isEqualTo("ACTIVE");

        // The category is still INACTIVE (never re-activated), yet the
        // business's own status is untouched and it's fully discoverable.
        ResponseEntity<Map> providerWhileCategoryInactive = restTemplate
                .getForEntity("/api/v1/providers/" + providerId, Map.class);
        assertThat(providerWhileCategoryInactive.getBody().get("status")).isEqualTo("ACTIVE");

        ResponseEntity<List> searchWhileCategoryInactive = restTemplate
                .getForEntity("/api/v1/search/providers?vertical=" + code, List.class);
        assertThat(searchWhileCategoryInactive.getBody()).anySatisfy(
                entry -> assertThat(((Map<?, ?>) entry).get("id")).isEqualTo(providerId.toString()));

        // Launching the vertical (INACTIVE -> ACTIVE) is purely additive:
        // the category becomes pickable again, the already-ACTIVE business
        // is untouched (it was never hidden to begin with) and stays exactly
        // as discoverable as it already was.
        ResponseEntity<Map> reactivated = restTemplate.exchange(
                "/api/v1/platform/categories/" + categoryId + "/status", HttpMethod.PATCH,
                new HttpEntity<>(Map.of("status", "ACTIVE"),
                        TestPlatformAuth.authHeaders(platformAdmin.accessToken())),
                Map.class);
        assertThat(reactivated.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<List> categoriesAfterLaunch = restTemplate.getForEntity("/api/v1/categories", List.class);
        assertThat(categoriesAfterLaunch.getBody())
                .anySatisfy(entry -> assertThat(((Map<?, ?>) entry).get("code")).isEqualTo(code));

        ResponseEntity<Map> providerAfterLaunch = restTemplate
                .getForEntity("/api/v1/providers/" + providerId, Map.class);
        assertThat(providerAfterLaunch.getBody().get("status")).isEqualTo("ACTIVE");
    }

    @Test
    void everySeededCategoryHasStarterCatalogServices() {
        // Other tests in this suite create their own categories and business
        // types (no services) in the same database, so only the categories
        // seeded by V25/V39/V41 are checked here.
        Set<String> seededCategoryCodes = Set.of("beauty", "medicine", "auto", "home_repair", "sport_fitness",
                "education", "kids", "animals", "photo_video", "weddings", "legal", "it_digital", "food", "fashion",
                "real_estate", "tourism", "household_services", "entertainment", "business_services", "events",
                "cleaning");

        ResponseEntity<List> categories = restTemplate.getForEntity("/api/v1/categories", List.class);
        assertThat(categories.getStatusCode()).isEqualTo(HttpStatus.OK);

        Set<String> categoriesWithServices = new HashSet<>();
        for (Object categoryEntry : categories.getBody()) {
            Map<?, ?> category = (Map<?, ?>) categoryEntry;
            String categoryCode = (String) category.get("code");
            if (!seededCategoryCodes.contains(categoryCode)) {
                continue;
            }
            ResponseEntity<List> businessTypes = restTemplate.getForEntity(
                    "/api/v1/categories/" + category.get("id") + "/business-types", List.class);
            for (Object businessTypeEntry : businessTypes.getBody()) {
                Map<?, ?> businessType = (Map<?, ?>) businessTypeEntry;
                ResponseEntity<List> services = restTemplate.getForEntity(
                        "/api/v1/business-types/" + businessType.get("id") + "/services", List.class);
                assertThat(services.getStatusCode()).isEqualTo(HttpStatus.OK);
                assertThat(services.getBody())
                        .as("starter services for business type %s", businessType.get("code"))
                        .isNotEmpty()
                        .allSatisfy(entry -> {
                            Map<?, ?> service = (Map<?, ?>) entry;
                            assertThat(service.get("nameKk")).asString().isNotBlank();
                            assertThat(service.get("nameRu")).asString().isNotBlank();
                            assertThat(service.get("nameEn")).asString().isNotBlank();
                        });
                categoriesWithServices.add(categoryCode);
            }
        }
        assertThat(categoriesWithServices).containsExactlyInAnyOrderElementsOf(seededCategoryCodes);

        ResponseEntity<List> beautySalonServices = restTemplate.getForEntity(
                "/api/v1/business-types/" + SEEDED_BEAUTY_SALON_BUSINESS_TYPE_ID + "/services", List.class);
        assertThat(beautySalonServices.getBody()).anySatisfy(entry -> {
            Map<?, ?> service = (Map<?, ?>) entry;
            assertThat(service.get("nameEn")).isEqualTo("Manicure");
        });
    }

    @Test
    void largeBusinessTypesGroupTheirServicesIntoSubspheres() {
        ResponseEntity<List> subspheres = restTemplate.getForEntity(
                "/api/v1/business-types/" + SEEDED_BEAUTY_SALON_BUSINESS_TYPE_ID + "/subspheres", List.class);
        assertThat(subspheres.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(subspheres.getBody()).extracting(entry -> ((Map<?, ?>) entry).get("code"))
                .contains("beauty_salon_hair", "beauty_salon_nails", "beauty_salon_face");

        Map<?, ?> hair = (Map<?, ?>) subspheres.getBody().stream()
                .filter(entry -> "beauty_salon_hair".equals(((Map<?, ?>) entry).get("code")))
                .findFirst().orElseThrow();
        ResponseEntity<List> hairServices = restTemplate.getForEntity(
                "/api/v1/subspheres/" + hair.get("id") + "/services", List.class);
        assertThat(hairServices.getBody()).extracting(entry -> ((Map<?, ?>) entry).get("nameEn"))
                .contains("Women's haircut", "Hair coloring");
    }
}
