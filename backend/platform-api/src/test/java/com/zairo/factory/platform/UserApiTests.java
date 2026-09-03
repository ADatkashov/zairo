package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.users.UserRepository;
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
 * GET /api/v1/users/{id} is admin-only (see UserController's doc comment) —
 * it returns another user's email/phone/role, which nothing but admin
 * tooling needs; a caller wanting their own account uses GET /auth/me
 * instead. These tests are the regression coverage that endpoint never had.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class UserApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Test
    void gettingAUserByIdWithoutATokenIs401() {
        Registered target = TestAuth.registerCustomer(restTemplate, "user-lookup-target-" + UUID.randomUUID()
                + "@example.com");

        ResponseEntity<Map> response = restTemplate.getForEntity("/api/v1/users/" + target.userId(), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void gettingAUserByIdAsANonAdminIs403() {
        Registered target = TestAuth.registerCustomer(restTemplate, "user-lookup-target-" + UUID.randomUUID()
                + "@example.com");
        Registered caller = TestAuth.registerCustomer(restTemplate, "user-lookup-caller-" + UUID.randomUUID()
                + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/users/" + target.userId(), HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(caller.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void gettingAUserByIdAsAnAdminReturnsIt() {
        Registered target = TestAuth.registerCustomer(restTemplate, "user-lookup-target-" + UUID.randomUUID()
                + "@example.com");
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "user-lookup-admin-" + UUID.randomUUID() + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/users/" + target.userId(), HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(admin.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("id")).isEqualTo(target.userId().toString());
    }

    @Test
    void gettingAnUnknownUserIdAsAnAdminIs404() {
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "user-lookup-admin-" + UUID.randomUUID() + "@example.com");

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/users/" + UUID.randomUUID(), HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(admin.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
