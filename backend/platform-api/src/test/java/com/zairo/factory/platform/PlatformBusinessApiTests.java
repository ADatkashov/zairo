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
 * The Control Center's business moderation path (ProviderAdminController) —
 * the same Provider row the legacy {@code UserRole.ADMIN} login moderates
 * through {@code PATCH /api/v1/providers/{id}/status}, now also reachable by
 * PLATFORM_ADMIN/PLATFORM_MODERATOR, audit-logged.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class PlatformBusinessApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void moderatorCanApproveAndSupportCannot() {
        var owner = TestAuth.registerOwner(restTemplate, "platform-business-owner-" + UUID.randomUUID() + "@example.com");
        var createRequest = new CreateProviderRequest(owner.userId(), "Test Salon For Moderation", "beauty");
        ResponseEntity<Map> createResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString((String) createResponse.getBody().get("id"));

        var moderator = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "business-moderator-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_MODERATOR);
        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "business-support-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);

        // PLATFORM_SUPPORT can read the moderation list...
        ResponseEntity<List> listAsSupport = restTemplate.exchange("/api/v1/platform/businesses?status=PENDING",
                HttpMethod.GET, new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())),
                List.class);
        assertThat(listAsSupport.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(listAsSupport.getBody()).anySatisfy(entry -> assertThat(((Map<?, ?>) entry).get("id"))
                .isEqualTo(providerId.toString()));

        // ...but can't mutate it.
        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/platform/businesses/" + providerId + "/status",
                HttpMethod.PATCH,
                new HttpEntity<>(Map.of("status", "ACTIVE"), TestPlatformAuth.authHeaders(support.accessToken())),
                Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // PLATFORM_MODERATOR can approve it.
        ResponseEntity<Map> approved = restTemplate.exchange("/api/v1/platform/businesses/" + providerId + "/status",
                HttpMethod.PATCH,
                new HttpEntity<>(Map.of("status", "ACTIVE", "reason", "Verified documents"),
                        TestPlatformAuth.authHeaders(moderator.accessToken())),
                Map.class);
        assertThat(approved.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(approved.getBody().get("status")).isEqualTo("ACTIVE");

        // Audit-logged.
        ResponseEntity<Map> auditLog = restTemplate.exchange("/api/v1/platform/audit-log?size=100", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(moderator.accessToken())), Map.class);
        List<Map<String, Object>> entries = (List<Map<String, Object>>) auditLog.getBody().get("content");
        assertThat(entries).anySatisfy(entry -> {
            assertThat(entry.get("action")).isEqualTo("PROVIDER_STATUS_CHANGED");
            assertThat(entry.get("targetId")).isEqualTo(providerId.toString());
        });
    }

    @Test
    void overviewGivesTheModeratorTheOwnerAndTheBusinessSizeAndIsPlatformOnly() {
        String runId = UUID.randomUUID().toString();
        var owner = TestAuth.registerOwner(restTemplate, "overview-owner-" + runId + "@example.com");
        var createRequest = new CreateProviderRequest(owner.userId(), "Overview Salon " + runId, "beauty");
        ResponseEntity<Map> createResponse = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestAuth.authHeaders(owner.accessToken())), Map.class);
        UUID providerId = UUID.fromString((String) createResponse.getBody().get("id"));
        restTemplate.exchange("/api/v1/providers/" + providerId + "/services", HttpMethod.POST,
                new HttpEntity<>(Map.of("title", "Haircut", "durationMinutes", 30, "price", 40, "currency", "USD"),
                        TestAuth.authHeaders(owner.accessToken())),
                Map.class);

        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "overview-support-" + runId + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);

        ResponseEntity<Map> overview = restTemplate.exchange("/api/v1/platform/businesses/" + providerId + "/overview",
                HttpMethod.GET, new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())), Map.class);
        assertThat(overview.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(overview.getBody().get("ownerEmail")).isEqualTo("overview-owner-" + runId + "@example.com");
        assertThat(overview.getBody().get("servicesCount")).isEqualTo(1);
        assertThat(overview.getBody().get("totalBookings")).isEqualTo(0);
        assertThat(overview.getBody().get("completedBookings")).isEqualTo(0);

        // An owner's own login is not a platform credential at all: EndpointAuthorizationManager treats a
        // customer/business token on a platform endpoint as no credential (401), not "known but not allowed".
        ResponseEntity<Map> asOwner = restTemplate.exchange("/api/v1/platform/businesses/" + providerId + "/overview",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(asOwner.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // An unknown business is a 404, not an empty card.
        ResponseEntity<Map> unknown = restTemplate.exchange("/api/v1/platform/businesses/" + UUID.randomUUID()
                + "/overview", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())), Map.class);
        assertThat(unknown.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
