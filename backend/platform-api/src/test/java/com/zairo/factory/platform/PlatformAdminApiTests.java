package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.LoginRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformAdminDtos.CreateAdminRequest;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.users.UserRole;
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
 * Against a real Postgres (Testcontainers) — proves the platform-admin auth
 * pipeline is genuinely separate from {@code /api/v1/auth}, not just
 * differently named: a real customer/business access token from
 * {@code /auth/login} must not work against any {@code /platform/**}
 * endpoint (see {@code rejectsACustomerBusinessTokenEntirely}).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class PlatformAdminApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void unknownEmailIsRejectedOnLogin() {
        var request = new com.zairo.factory.platformadmin.PlatformAdminDtos.LoginRequest(
                "nobody-" + UUID.randomUUID() + "@factory.internal", "whatever123");

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/platform/auth/login", request, Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void platformAdminLogsInAndReadsOwnAccount() {
        String email = "admin-" + UUID.randomUUID() + "@factory.internal";
        var admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository, email,
                PlatformRole.PLATFORM_ADMIN);

        ResponseEntity<Map> me = restTemplate.exchange("/api/v1/platform/auth/me", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);

        assertThat(me.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(me.getBody().get("email")).isEqualTo(email);
        assertThat(me.getBody().get("role")).isEqualTo("PLATFORM_ADMIN");
    }

    @Test
    void platformAdminCreatesAnotherAccountAndItAppearsInTheAuditLog() {
        String adminEmail = "admin-" + UUID.randomUUID() + "@factory.internal";
        var admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository, adminEmail,
                PlatformRole.PLATFORM_ADMIN);
        String newEmail = "support-" + UUID.randomUUID() + "@factory.internal";
        var createRequest = new CreateAdminRequest(newEmail, "password123", "New Support", PlatformRole.PLATFORM_SUPPORT,
                "Onboarding a new hire");

        ResponseEntity<Map> createResponse = restTemplate.exchange("/api/v1/platform/admins", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getBody().get("email")).isEqualTo(newEmail);

        // Duplicate email is rejected.
        ResponseEntity<Map> duplicate = restTemplate.exchange("/api/v1/platform/admins", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(duplicate.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // The creation is on the audit log.
        ResponseEntity<Map> auditLog = restTemplate.exchange("/api/v1/platform/audit-log?size=50", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(auditLog.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<Map<String, Object>> entries = (List<Map<String, Object>>) auditLog.getBody().get("content");
        assertThat(entries).anySatisfy(entry -> {
            assertThat(entry.get("action")).isEqualTo("PLATFORM_ADMIN_CREATED");
            assertThat(entry.get("actorEmail")).isEqualTo(adminEmail);
            assertThat(entry.get("newValue")).isEqualTo("PLATFORM_SUPPORT");
        });
    }

    @Test
    void platformSupportCannotCreateAccountsButCanReadTheAuditLog() {
        String email = "support-" + UUID.randomUUID() + "@factory.internal";
        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository, email,
                PlatformRole.PLATFORM_SUPPORT);
        var createRequest = new CreateAdminRequest("blocked-" + UUID.randomUUID() + "@factory.internal",
                "password123", "Blocked", PlatformRole.PLATFORM_SUPPORT, null);

        ResponseEntity<Map> createResponse = restTemplate.exchange("/api/v1/platform/admins", HttpMethod.POST,
                new HttpEntity<>(createRequest, TestPlatformAuth.authHeaders(support.accessToken())), Map.class);
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Map> auditLog = restTemplate.exchange("/api/v1/platform/audit-log", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())), Map.class);
        assertThat(auditLog.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    /** The core property this whole module exists to guarantee. */
    @Test
    void rejectsACustomerBusinessTokenEntirely() {
        String email = "customer-" + UUID.randomUUID() + "@example.com";
        var registerRequest = new RegisterRequest(email, "password123", "Regular Customer", "+1000000006",
                UserRole.CUSTOMER);
        Map<?, ?> registerBody = restTemplate.postForEntity("/api/v1/auth/register", registerRequest, Map.class)
                .getBody();
        String customerAccessToken = registerBody.get("accessToken").toString();

        ResponseEntity<Map> me = restTemplate.exchange("/api/v1/platform/auth/me", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(customerAccessToken)), Map.class);

        assertThat(me.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // Symmetrically, a real customer login request shape is irrelevant here
        // — sanity-check the reverse direction too, using /auth/login's own token.
        Map<?, ?> loginBody = restTemplate.postForEntity("/api/v1/auth/login",
                new LoginRequest(email, "password123"), Map.class).getBody();
        String loginAccessToken = loginBody.get("accessToken").toString();
        ResponseEntity<Map> auditLog = restTemplate.exchange("/api/v1/platform/audit-log", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(loginAccessToken)), Map.class);
        assertThat(auditLog.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
