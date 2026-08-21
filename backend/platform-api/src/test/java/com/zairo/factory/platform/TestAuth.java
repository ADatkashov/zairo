package com.zairo.factory.platform;

import com.zairo.factory.auth.AuthDtos.LoginRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.auth.Credential;
import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.users.UserRole;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Shared helper for *ApiTests classes that need a real, authenticated
 * PROVIDER_OWNER — most now do, since provider/service/slot/master
 * creation and every edit/delete endpoint requires proving ownership (see
 * CurrentUser/ProviderOwnership). Registers via /auth/register (not the
 * old passwordless /api/v1/users) so there's a real access token to send.
 */
final class TestAuth {

    private TestAuth() {
    }

    record Registered(UUID userId, String accessToken) {
    }

    static Registered registerOwner(TestRestTemplate restTemplate, String email) {
        var request = new RegisterRequest(email, "password123", "Registered Owner", "+1000000002",
                UserRole.PROVIDER_OWNER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/auth/register", request, Map.class).getBody();
        UUID userId = UUID.fromString(((Map<?, ?>) body.get("user")).get("id").toString());
        return new Registered(userId, body.get("accessToken").toString());
    }

    static Registered registerCustomer(TestRestTemplate restTemplate, String email) {
        var request = new RegisterRequest(email, "password123", "Registered Customer", "+1000000003",
                UserRole.CUSTOMER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/auth/register", request, Map.class).getBody();
        UUID userId = UUID.fromString(((Map<?, ?>) body.get("user")).get("id").toString());
        return new Registered(userId, body.get("accessToken").toString());
    }

    static HttpHeaders authHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return headers;
    }

    /**
     * ADMIN is deliberately not self-registerable via /auth/register (see
     * AuthService.register) — the only way to get one is direct DB
     * creation, same as a real deployment ("granted manually"). Tests
     * mirror that by writing the User/Credential rows straight through the
     * repositories instead of going through the public endpoint, then
     * logging in normally to get a real token.
     */
    static Registered registerAdmin(TestRestTemplate restTemplate, UserRepository userRepository,
            CredentialRepository credentialRepository, String email) {
        String password = "password123";
        User user = userRepository.save(new User(UUID.randomUUID(), email, "+1000000004", "Test Admin",
                UserRole.ADMIN, Instant.now()));
        credentialRepository.save(new Credential(UUID.randomUUID(), user.getId(),
                new BCryptPasswordEncoder().encode(password), Instant.now()));

        Map<?, ?> body = restTemplate.postForEntity("/api/v1/auth/login", new LoginRequest(email, password),
                Map.class).getBody();
        return new Registered(user.getId(), body.get("accessToken").toString());
    }
}
