package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.LoginRequest;
import com.zairo.factory.auth.AuthDtos.RefreshRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.users.UserRole;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Against a real Postgres (Testcontainers): register -> login -> /me with
 * the access token -> refresh (rotates the token, old one stops working) ->
 * duplicate email rejected, wrong password rejected, /me without a token
 * rejected.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class AuthApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void registersLogsInAndRefreshesTokens() {
        String runId = UUID.randomUUID().toString();
        String email = "auth-" + runId + "@example.com";
        var registerRequest = new RegisterRequest(email, "correct horse battery staple", "Auth Test User",
                "+1000000000", UserRole.CUSTOMER);

        ResponseEntity<Map> registerResponse = restTemplate.postForEntity("/api/v1/auth/register", registerRequest,
                Map.class);
        assertThat(registerResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String accessToken = (String) registerResponse.getBody().get("accessToken");
        String refreshToken = (String) registerResponse.getBody().get("refreshToken");
        assertThat(accessToken).isNotBlank();
        assertThat(refreshToken).isNotBlank();

        // Duplicate registration is rejected.
        ResponseEntity<Map> duplicate = restTemplate.postForEntity("/api/v1/auth/register", registerRequest,
                Map.class);
        assertThat(duplicate.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        // /me without a token is rejected.
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/auth/me", Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // /me with the access token succeeds.
        ResponseEntity<Map> me = restTemplate.exchange("/api/v1/auth/me", HttpMethod.GET, authorized(accessToken),
                Map.class);
        assertThat(me.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(me.getBody().get("email")).isEqualTo(email);

        // Wrong password is rejected.
        var badLogin = new LoginRequest(email, "wrong password");
        ResponseEntity<Map> badLoginResponse = restTemplate.postForEntity("/api/v1/auth/login", badLogin,
                Map.class);
        assertThat(badLoginResponse.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // Correct login succeeds and issues a fresh token pair.
        var loginRequest = new LoginRequest(email, "correct horse battery staple");
        ResponseEntity<Map> loginResponse = restTemplate.postForEntity("/api/v1/auth/login", loginRequest,
                Map.class);
        assertThat(loginResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Refresh rotates the token: old refresh token stops working, new
        // one is returned and works.
        ResponseEntity<Map> refreshResponse = restTemplate.postForEntity("/api/v1/auth/refresh",
                new RefreshRequest(refreshToken), Map.class);
        assertThat(refreshResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        String newRefreshToken = (String) refreshResponse.getBody().get("refreshToken");
        assertThat(newRefreshToken).isNotEqualTo(refreshToken);

        ResponseEntity<Map> reuseOldRefreshToken = restTemplate.postForEntity("/api/v1/auth/refresh",
                new RefreshRequest(refreshToken), Map.class);
        assertThat(reuseOldRefreshToken.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    /** ADMIN must be granted directly in the database — see AuthService.register's doc comment. */
    @Test
    void rejectsSelfRegistrationAsAdmin() {
        var registerRequest = new RegisterRequest("wannabe-admin-" + UUID.randomUUID() + "@example.com",
                "password123", "Wannabe Admin", "+1000000001", UserRole.ADMIN);

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/register", registerRequest,
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    private HttpEntity<Void> authorized(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return new HttpEntity<>(headers);
    }
}
