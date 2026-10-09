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
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
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

    /**
     * Makes the provider charge the full price online. A provider takes no advance payment by default, and
     * a booking with nothing due online is confirmed on creation with no payment at all — so a test that
     * walks a booking through "pay -> confirm" (and everything that hangs off a payment: commission,
     * payout, refund) first has to ask for an online payment.
     */
    static void requireFullPayment(TestRestTemplate restTemplate, Registered owner, UUID providerId) {
        var response = restTemplate.exchange("/api/v1/payment-settings?providerId=" + providerId, HttpMethod.PUT,
                new HttpEntity<>(Map.of("depositType", "FULL_PAYMENT"), authHeaders(owner.accessToken())),
                Map.class);
        if (!response.getStatusCode().is2xxSuccessful()) {
            throw new IllegalStateException("Could not require full payment: " + response.getStatusCode());
        }
    }

    static HttpHeaders authHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return headers;
    }

    /**
     * For tests unrelated to billing that need an owner unconstrained by the
     * FREE plan's limits (e.g. more than one provider, or recurring-schedule
     * generation) — the plain MockPaymentProvider always succeeds, so this
     * needs no special payment test-config. See SubscriptionApiTests for the
     * tests that actually exercise the FREE-plan limits themselves.
     */
    static void upgradeToPro(TestRestTemplate restTemplate, Registered owner) {
        restTemplate.exchange("/api/v1/subscriptions/upgrade", HttpMethod.POST,
                new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
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
