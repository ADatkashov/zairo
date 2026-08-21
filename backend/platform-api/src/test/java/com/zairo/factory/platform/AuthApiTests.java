package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.ForgotPasswordRequest;
import com.zairo.factory.auth.AuthDtos.LoginRequest;
import com.zairo.factory.auth.AuthDtos.RefreshRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.auth.AuthDtos.ResetPasswordRequest;
import com.zairo.factory.users.UserRole;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
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
@Import({TestcontainersConfiguration.class, TestNotifications.class})
class AuthApiTests {

    private static final Pattern RESET_CODE_PATTERN = Pattern.compile("reset your password: (\\S+)");

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestNotifications.CapturedEmails capturedEmails;

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

    @Test
    void resetsPasswordWithACodeThenTheOldPasswordAndSessionStopWorking() {
        String runId = UUID.randomUUID().toString();
        String email = "reset-" + runId + "@example.com";
        var registerRequest = new RegisterRequest(email, "old password 123", "Reset Test User", "+1000000005",
                UserRole.CUSTOMER);
        Map<?, ?> registerBody = restTemplate.postForEntity("/api/v1/auth/register", registerRequest, Map.class)
                .getBody();
        String originalRefreshToken = (String) registerBody.get("refreshToken");

        ResponseEntity<Void> forgotResponse = restTemplate.postForEntity("/api/v1/auth/forgot-password",
                new ForgotPasswordRequest(email), Void.class);
        assertThat(forgotResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        TestNotifications.CapturedEmail resetEmail = capturedEmails.sent.stream()
                .filter(sent -> sent.toEmail().equals(email))
                .findFirst()
                .orElseThrow(() -> new AssertionError("No reset email captured for " + email));
        String resetCode = extractResetCode(resetEmail.body());

        ResponseEntity<Void> resetResponse = restTemplate.postForEntity("/api/v1/auth/reset-password",
                new ResetPasswordRequest(resetCode, "new password 456"), Void.class);
        assertThat(resetResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Old password no longer works, new password does.
        ResponseEntity<Map> oldPasswordLogin = restTemplate.postForEntity("/api/v1/auth/login",
                new LoginRequest(email, "old password 123"), Map.class);
        assertThat(oldPasswordLogin.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        ResponseEntity<Map> newPasswordLogin = restTemplate.postForEntity("/api/v1/auth/login",
                new LoginRequest(email, "new password 456"), Map.class);
        assertThat(newPasswordLogin.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The session that existed before the reset is revoked.
        ResponseEntity<Map> reuseOldSession = restTemplate.postForEntity("/api/v1/auth/refresh",
                new RefreshRequest(originalRefreshToken), Map.class);
        assertThat(reuseOldSession.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The reset code can't be used a second time.
        ResponseEntity<Void> reuseResetCode = restTemplate.postForEntity("/api/v1/auth/reset-password",
                new ResetPasswordRequest(resetCode, "yet another password"), Void.class);
        assertThat(reuseResetCode.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    /** No 404/different response for an unregistered email — see AuthService.forgotPassword's doc comment. */
    @Test
    void forgotPasswordDoesNotRevealWhetherTheEmailIsRegistered() {
        ResponseEntity<Void> response = restTemplate.postForEntity("/api/v1/auth/forgot-password",
                new ForgotPasswordRequest("nobody-" + UUID.randomUUID() + "@example.com"), Void.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @Test
    void resetPasswordRejectsAGarbageToken() {
        ResponseEntity<Void> response = restTemplate.postForEntity("/api/v1/auth/reset-password",
                new ResetPasswordRequest("not-a-real-token", "some password"), Void.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    private static String extractResetCode(String emailBody) {
        Matcher matcher = RESET_CODE_PATTERN.matcher(emailBody);
        assertThat(matcher.find()).as("reset code pattern found in email body: %s", emailBody).isTrue();
        return matcher.group(1);
    }

    private HttpEntity<Void> authorized(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return new HttpEntity<>(headers);
    }
}
