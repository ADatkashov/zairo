package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.LoginRequest;
import com.zairo.factory.auth.AuthDtos.RefreshRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.users.UserRole;
import java.util.HashMap;
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

/** Account deletion: confirmation + password gates, anonymization, freed sign-in, and the owner guard. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class})
class AccountDeletionApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    private ResponseEntity<Map> delete(String accessToken, String password, String confirmation) {
        Map<String, Object> body = new HashMap<>();
        body.put("password", password);
        body.put("confirmation", confirmation);
        return restTemplate.exchange("/api/v1/auth/me/delete", HttpMethod.POST,
                new HttpEntity<>(body, TestAuth.authHeaders(accessToken)), Map.class);
    }

    @Test
    void deletionNeedsTheTypedConfirmationAndTheRightPassword() {
        String email = "del-gate-" + UUID.randomUUID() + "@example.com";
        TestAuth.Registered user = TestAuth.registerCustomer(restTemplate, email);

        assertThat(delete(user.accessToken(), "password123", "nope").getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(delete(user.accessToken(), "wrong-password", "DELETE").getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(delete(user.accessToken(), null, "DELETE").getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // Nothing was deleted by the refused attempts.
        ResponseEntity<Map> me = restTemplate.exchange("/api/v1/auth/me", HttpMethod.GET,
                new HttpEntity<>(TestAuth.authHeaders(user.accessToken())), Map.class);
        assertThat(me.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @Test
    void aDeletedAccountIsAnonymizedCannotSignInAndFreesItsEmail() {
        String email = "del-ok-" + UUID.randomUUID() + "@example.com";
        var registerRequest = new RegisterRequest(email, "password123", "Aigerim Real Name", "+77001234567",
                UserRole.CUSTOMER);
        Map<?, ?> registered = restTemplate.postForEntity("/api/v1/auth/register", registerRequest, Map.class)
                .getBody();
        UUID userId = UUID.fromString(((Map<?, ?>) registered.get("user")).get("id").toString());
        String accessToken = registered.get("accessToken").toString();
        String refreshToken = registered.get("refreshToken").toString();

        assertThat(delete(accessToken, "password123", "DELETE").getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // The row stays (history keeps referencing it) but holds no personal data any more.
        var user = userRepository.findById(userId).orElseThrow();
        assertThat(user.isDeleted()).isTrue();
        assertThat(user.getEmail()).isNull();
        assertThat(user.getPhone()).isNull();
        assertThat(user.getDisplayName()).isEqualTo("Deleted user");

        // Signing in, refreshing and using the old token all stop working.
        assertThat(restTemplate.postForEntity("/api/v1/auth/login", new LoginRequest(email, "password123"),
                Map.class).getStatusCode().is2xxSuccessful()).isFalse();
        assertThat(restTemplate.postForEntity("/api/v1/auth/refresh", new RefreshRequest(refreshToken), Map.class)
                .getStatusCode().is2xxSuccessful()).isFalse();
        assertThat(restTemplate.exchange("/api/v1/auth/me", HttpMethod.GET,
                new HttpEntity<>(TestAuth.authHeaders(accessToken)), Map.class).getStatusCode())
                .isEqualTo(HttpStatus.UNAUTHORIZED);

        // The email is free again: the same person can start over with a brand-new account.
        TestAuth.Registered again = TestAuth.registerCustomer(restTemplate, email);
        assertThat(again.userId()).isNotEqualTo(userId);
    }

    @Test
    void anOwnerWhoStillOwnsABusinessCannotDeleteTheAccount() {
        String runId = UUID.randomUUID().toString();
        TestAuth.Registered owner = TestAuth.registerOwner(restTemplate, "del-owner-" + runId + "@example.com");
        var request = new CreateProviderRequest(owner.userId(), "Deletion Guard Salon " + runId, "beauty");
        ResponseEntity<Map> provider = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(provider.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<Map> response = delete(owner.accessToken(), "password123", "DELETE");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(userRepository.findById(owner.userId()).orElseThrow().isDeleted()).isFalse();
    }
}
