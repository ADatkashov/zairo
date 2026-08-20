package com.zairo.factory.platform;

import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.users.UserRole;
import java.util.Map;
import java.util.UUID;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.http.HttpHeaders;

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

    static HttpHeaders authHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return headers;
    }
}
