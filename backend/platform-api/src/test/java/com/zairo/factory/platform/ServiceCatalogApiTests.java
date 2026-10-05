package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.LinkCatalogServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.UpdateServiceRequest;
import java.math.BigDecimal;
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
 * Businesses don't write their own services: once a provider's catalog
 * business type has an active catalog, a service must be one of its catalog
 * services (see ServiceCatalogPolicy). Every test makes its own category ->
 * business type -> catalog services, and a provider whose vertical is that
 * category's code, so the seeded types the other test classes create
 * free-text services under are never affected.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class ServiceCatalogApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    /** A fresh catalog type with one ACTIVE service, and an owner with a provider of that type. */
    private record Setup(Registered owner, TestPlatformAuth.Registered admin, UUID providerId, UUID businessTypeId,
            UUID catalogServiceId, String catalogName) {
    }

    private Setup setUp() {
        String suffix = UUID.randomUUID().toString().replace("-", "");
        TestPlatformAuth.Registered admin = TestPlatformAuth.registerPlatformAdmin(restTemplate,
                platformAdminAccountRepository, "svc-cat-admin-" + suffix + "@factory.internal",
                PlatformRole.PLATFORM_ADMIN);
        String categoryCode = "svccat" + suffix;
        Map<?, ?> category = post(admin, "/api/v1/platform/categories", Map.of("code", categoryCode, "nameKk", "К",
                "nameRu", "К", "nameEn", "C", "sortOrder", 1));
        Map<?, ?> businessType = post(admin, "/api/v1/platform/business-types", Map.of("categoryId",
                category.get("id"), "code", "svcbt" + suffix, "nameKk", "Т", "nameRu", "Т", "nameEn", "T",
                "sortOrder", 1));
        UUID businessTypeId = UUID.fromString((String) businessType.get("id"));
        String catalogName = "Manicure " + suffix;
        UUID catalogServiceId = createCatalogService(admin, businessTypeId, catalogName);

        Registered owner = TestAuth.registerOwner(restTemplate, "svc-cat-owner-" + suffix + "@example.com");
        // The provider's vertical is the new category's code, so it resolves to the new business type.
        var providerRequest = new CreateProviderRequest(owner.userId(), "Catalog Salon " + suffix, categoryCode);
        ResponseEntity<Map> provider = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(provider.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(provider.getBody().get("businessTypeId")).isEqualTo(businessTypeId.toString());
        return new Setup(owner, admin, UUID.fromString(provider.getBody().get("id").toString()), businessTypeId,
                catalogServiceId, catalogName);
    }

    private UUID createCatalogService(TestPlatformAuth.Registered admin, UUID businessTypeId, String name) {
        Map<?, ?> created = post(admin, "/api/v1/platform/services", Map.of("businessTypeId", businessTypeId,
                "nameKk", name + " KK", "nameRu", name + " RU", "nameEn", name, "sortOrder", 1));
        return UUID.fromString((String) created.get("id"));
    }

    private Map<?, ?> post(TestPlatformAuth.Registered admin, String path, Object body) {
        ResponseEntity<Map> response = restTemplate.exchange(path, HttpMethod.POST,
                new HttpEntity<>(body, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return response.getBody();
    }

    private ResponseEntity<Map> createService(Setup s, CreateServiceRequest request) {
        return restTemplate.exchange("/api/v1/providers/" + s.providerId() + "/services", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(s.owner().accessToken())), Map.class);
    }

    private CreateServiceRequest request(String title, UUID catalogServiceId) {
        return new CreateServiceRequest(title, 30, new BigDecimal("20.00"), "USD", catalogServiceId);
    }

    @Test
    void aServiceMustComeFromTheCatalogOnceTheTypeHasOne() {
        Setup s = setUp();

        // A free-text service — the old way — is refused, and says why.
        ResponseEntity<Map> freeText = createService(s, new CreateServiceRequest("My own massage", 30,
                new BigDecimal("20.00"), "USD"));
        assertThat(freeText.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(freeText.getBody().toString()).contains("catalog");

        // Naming a catalog service but writing a different title is refused too.
        ResponseEntity<Map> mismatched = createService(s, request("My own massage", s.catalogServiceId()));
        assertThat(mismatched.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // The catalog service with its own name works and is linked right away.
        ResponseEntity<Map> ok = createService(s, request(s.catalogName(), s.catalogServiceId()));
        assertThat(ok.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(ok.getBody().get("catalogServiceId")).isEqualTo(s.catalogServiceId().toString());
        assertThat(ok.getBody().get("title")).isEqualTo(s.catalogName());

        // Any of the three language names is accepted as the title.
        assertThat(createService(s, request(s.catalogName() + " RU", s.catalogServiceId())).getStatusCode())
                .isEqualTo(HttpStatus.CREATED);
        assertThat(createService(s, request(s.catalogName() + " KK", s.catalogServiceId())).getStatusCode())
                .isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void aCatalogServiceOfAnotherKindOfBusinessOrAHiddenOneIsRefused() {
        Setup s = setUp();
        Setup other = setUp();

        // Another business type's catalog service can't be used.
        ResponseEntity<Map> foreign = createService(s, request(other.catalogName(), other.catalogServiceId()));
        assertThat(foreign.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // A made-up id is a 404, not a silent free-text fallback.
        ResponseEntity<Map> unknown = createService(s, request(s.catalogName(), UUID.randomUUID()));
        assertThat(unknown.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        // A second catalog service is created and then hidden by the platform: no longer pickable.
        String hiddenName = "Hidden " + UUID.randomUUID();
        UUID hidden = createCatalogService(s.admin(), s.businessTypeId(), hiddenName);
        ResponseEntity<Void> hide = restTemplate.exchange("/api/v1/platform/services/" + hidden + "/status",
                HttpMethod.PATCH, new HttpEntity<>(Map.of("status", "INACTIVE"),
                        TestPlatformAuth.authHeaders(s.admin().accessToken())), Void.class);
        assertThat(hide.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(createService(s, request(hiddenName, hidden)).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void editingIsHeldToTheSameRuleAndKeepsTheLink() {
        Setup s = setUp();
        ResponseEntity<Map> created = createService(s, request(s.catalogName(), s.catalogServiceId()));
        String serviceId = created.getBody().get("id").toString();
        var headers = TestAuth.authHeaders(s.owner().accessToken());

        // Renaming it to something the platform didn't define is refused.
        var freeText = new UpdateServiceRequest("Renamed by owner", 45, new BigDecimal("30.00"), "USD",
                s.catalogServiceId());
        assertThat(restTemplate.exchange("/api/v1/services/" + serviceId, HttpMethod.PUT,
                new HttpEntity<>(freeText, headers), Map.class).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // So is dropping the catalog link.
        var noLink = new UpdateServiceRequest(s.catalogName(), 45, new BigDecimal("30.00"), "USD");
        assertThat(restTemplate.exchange("/api/v1/services/" + serviceId, HttpMethod.PUT,
                new HttpEntity<>(noLink, headers), Map.class).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // Price and duration can change freely; the link stays.
        var ok = new UpdateServiceRequest(s.catalogName(), 45, new BigDecimal("30.00"), "USD", s.catalogServiceId());
        ResponseEntity<Map> updated = restTemplate.exchange("/api/v1/services/" + serviceId, HttpMethod.PUT,
                new HttpEntity<>(ok, headers), Map.class);
        assertThat(updated.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updated.getBody().get("durationMinutes")).isEqualTo(45);
        assertThat(updated.getBody().get("catalogServiceId")).isEqualTo(s.catalogServiceId().toString());
    }

    @Test
    void theLinkCannotBeRemovedOrPointedAtTheWrongCatalogService() {
        Setup s = setUp();
        Setup other = setUp();
        String serviceId = createService(s, request(s.catalogName(), s.catalogServiceId())).getBody().get("id")
                .toString();
        var headers = TestAuth.authHeaders(s.owner().accessToken());

        ResponseEntity<Map> unlink = restTemplate.exchange("/api/v1/services/" + serviceId + "/catalog-link",
                HttpMethod.PATCH, new HttpEntity<>(new LinkCatalogServiceRequest(null), headers), Map.class);
        assertThat(unlink.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<Map> foreign = restTemplate.exchange("/api/v1/services/" + serviceId + "/catalog-link",
                HttpMethod.PATCH, new HttpEntity<>(new LinkCatalogServiceRequest(other.catalogServiceId()), headers),
                Map.class);
        assertThat(foreign.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // Pointing it at another service of the same type is fine.
        UUID sibling = createCatalogService(s.admin(), s.businessTypeId(), "Sibling " + UUID.randomUUID());
        ResponseEntity<Map> relink = restTemplate.exchange("/api/v1/services/" + serviceId + "/catalog-link",
                HttpMethod.PATCH, new HttpEntity<>(new LinkCatalogServiceRequest(sibling), headers), Map.class);
        assertThat(relink.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(relink.getBody().get("catalogServiceId")).isEqualTo(sibling.toString());
    }

    @Test
    void freeTextStaysAllowedWhereThereIsNoCatalogToPickFrom() {
        // A type nobody has filled in yet: refusing would leave the business unable to add anything.
        String suffix = UUID.randomUUID().toString().replace("-", "");
        TestPlatformAuth.Registered admin = TestPlatformAuth.registerPlatformAdmin(restTemplate,
                platformAdminAccountRepository, "svc-empty-admin-" + suffix + "@factory.internal",
                PlatformRole.PLATFORM_ADMIN);
        String categoryCode = "svcempty" + suffix;
        Map<?, ?> category = post(admin, "/api/v1/platform/categories", Map.of("code", categoryCode, "nameKk", "К",
                "nameRu", "К", "nameEn", "C", "sortOrder", 1));
        post(admin, "/api/v1/platform/business-types", Map.of("categoryId", category.get("id"), "code",
                "svcemptybt" + suffix, "nameKk", "Т", "nameRu", "Т", "nameEn", "T", "sortOrder", 1));
        Registered owner = TestAuth.registerOwner(restTemplate, "svc-empty-owner-" + suffix + "@example.com");
        var providerRequest = new CreateProviderRequest(owner.userId(), "Empty Catalog Salon " + suffix,
                categoryCode);
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());

        var freeText = new CreateServiceRequest("Haircut", 30, new BigDecimal("20.00"), "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(freeText, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().get("catalogServiceId")).isNull();
    }
}
