package com.zairo.factory.platform;

import com.zairo.factory.platformadmin.PlatformAdminAccount;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformAdminDtos.LoginRequest;
import com.zairo.factory.platformadmin.PlatformRole;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Mirrors {@code TestAuth.registerAdmin} — platform accounts have no public
 * self-registration endpoint (see {@code PlatformAdminController}'s doc
 * comment), so tests seed one directly through the repository, exactly as a
 * real deployment's first platform admin would be created, then log in
 * normally for a real token.
 */
final class TestPlatformAuth {

    private TestPlatformAuth() {
    }

    record Registered(UUID adminId, String email, String accessToken) {
    }

    static Registered registerPlatformAdmin(TestRestTemplate restTemplate,
            PlatformAdminAccountRepository accountRepository, String email, PlatformRole role) {
        String password = "password123";
        PlatformAdminAccount account = accountRepository.save(new PlatformAdminAccount(UUID.randomUUID(), email,
                new BCryptPasswordEncoder().encode(password), "Test Platform Staff", role, Instant.now()));

        Map<?, ?> body = restTemplate.postForEntity("/api/v1/platform/auth/login", new LoginRequest(email, password),
                Map.class).getBody();
        return new Registered(account.getId(), email, body.get("accessToken").toString());
    }

    static HttpHeaders authHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return headers;
    }
}
