package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
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
 * The platform role rules are annotations on the endpoints ({@code @PlatformAdminOnly},
 * {@code @PlatformModerationCapable}, {@code @AnyPlatformRole}) enforced by Spring Security's
 * method security — one row of each kind here, for every role and for the wrong token family.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class PlatformRoleAnnotationsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository accounts;

    private String token(PlatformRole role) {
        return TestPlatformAuth.registerPlatformAdmin(restTemplate, accounts,
                "role-" + role + "-" + UUID.randomUUID() + "@factory.internal", role).accessToken();
    }

    private HttpStatus call(HttpMethod method, String url, String token) {
        ResponseEntity<String> response = restTemplate.exchange(url, method,
                new HttpEntity<>(token == null ? null : TestPlatformAuth.authHeaders(token)), String.class);
        return HttpStatus.valueOf(response.getStatusCode().value());
    }

    @Test
    void adminOnlyEndpointsRefuseModeratorAndSupportButNotTheAdmin() {
        String url = "/api/v1/platform/cities/no-such-city";

        assertThat(call(HttpMethod.DELETE, url, token(PlatformRole.PLATFORM_SUPPORT))).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(call(HttpMethod.DELETE, url, token(PlatformRole.PLATFORM_MODERATOR))).isEqualTo(HttpStatus.FORBIDDEN);
        // Past the role check the admin reaches the handler (the city simply does not exist).
        assertThat(call(HttpMethod.DELETE, url, token(PlatformRole.PLATFORM_ADMIN))).isNotIn(HttpStatus.FORBIDDEN,
                HttpStatus.UNAUTHORIZED);
        assertThat(call(HttpMethod.DELETE, url, null)).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void readEndpointsOpenToEveryPlatformRole() {
        String url = "/api/v1/platform/payments/failed-refunds";

        for (PlatformRole role : PlatformRole.values()) {
            assertThat(call(HttpMethod.GET, url, token(role))).as(role.name()).isEqualTo(HttpStatus.OK);
        }
        assertThat(call(HttpMethod.GET, url, null)).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void aCustomerTokenNeverOpensAPlatformEndpoint() {
        var owner = TestAuth.registerOwner(restTemplate, "role-owner-" + UUID.randomUUID() + "@example.com");

        HttpStatus read = call(HttpMethod.GET, "/api/v1/platform/payments/failed-refunds", owner.accessToken());
        HttpStatus write = call(HttpMethod.DELETE, "/api/v1/platform/cities/no-such-city", owner.accessToken());

        // Not a platform credential at all: 401, the same as no token (not "known but forbidden").
        assertThat(read).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(write).isEqualTo(HttpStatus.UNAUTHORIZED);
        // Also for a platform-only endpoint that does not live under /platform/.
        assertThat(call(HttpMethod.POST, "/api/v1/payments/" + UUID.randomUUID() + "/refund", owner.accessToken()))
                .isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void aPlatformTokenNeverOpensACustomerEndpoint() {
        String admin = token(PlatformRole.PLATFORM_ADMIN);

        HttpStatus status = call(HttpMethod.GET,
                "/api/v1/users/00000000-0000-0000-0000-000000000001/bookings", admin);

        assertThat(status).isIn(HttpStatus.UNAUTHORIZED, HttpStatus.FORBIDDEN);
    }
}
