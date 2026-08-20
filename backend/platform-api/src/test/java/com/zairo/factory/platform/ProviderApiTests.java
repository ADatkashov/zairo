package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.UpdateServiceRequest;
import com.zairo.factory.users.UserRepository;
import java.math.BigDecimal;
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
 * End-to-end check of the users -> providers -> services flow through real
 * HTTP + a real Postgres (Testcontainers), exercising Flyway migrations and
 * JPA mappings together rather than each module in isolation.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class ProviderApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Test
    void createsOwnerThenProviderThenService() {
        Registered owner = TestAuth.registerOwner(restTemplate, "owner@example.com");
        UUID providerId = createProvider(owner, "Best Beauty Salon");

        var serviceRequest = new CreateServiceRequest("Haircut", 45, new BigDecimal("30.00"), "USD");
        ResponseEntity<Object> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/services", HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(
                owner.accessToken())), Object.class);
        assertThat(serviceResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<Object[]> listResponse = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/services", Object[].class);
        assertThat(listResponse.getBody()).hasSize(1);
    }

    @Test
    void cannotCreateAProviderOrServiceForSomeoneElse() {
        Registered owner = TestAuth.registerOwner(restTemplate, "impersonation-owner@example.com");
        Registered attacker = TestAuth.registerOwner(restTemplate, "impersonation-attacker@example.com");

        // Claiming someone else as the owner, even while authenticated as yourself, is rejected.
        var spoofedRequest = new CreateProviderRequest(owner.userId(), "Spoofed Salon", "beauty");
        ResponseEntity<Object> spoofed = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(spoofedRequest, TestAuth.authHeaders(attacker.accessToken())), Object.class);
        assertThat(spoofed.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // No token at all is rejected too.
        var anonymousRequest = new CreateProviderRequest(owner.userId(), "Anonymous Salon", "beauty");
        ResponseEntity<Object> anonymous = restTemplate.postForEntity("/api/v1/providers", anonymousRequest,
                Object.class);
        assertThat(anonymous.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        UUID providerId = createProvider(owner, "Real Salon");

        // Attacker can't create a service under a provider they don't own either.
        var serviceRequest = new CreateServiceRequest("Haircut", 30, new BigDecimal("20.00"), "USD");
        ResponseEntity<Object> forbiddenService = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/services", HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(
                attacker.accessToken())), Object.class);
        assertThat(forbiddenService.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void updatesThenDeactivatesAService() {
        Registered owner = TestAuth.registerOwner(restTemplate, "service-edit-owner@example.com");
        UUID providerId = createProvider(owner, "Service Edit Salon");
        UUID serviceId = createService(owner, providerId, "Haircut", new BigDecimal("25.00"));

        var updateRequest = new UpdateServiceRequest("Haircut & Style", 45, new BigDecimal("35.00"), "USD");
        ResponseEntity<java.util.Map> updateResponse = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.PUT, new HttpEntity<>(updateRequest, TestAuth.authHeaders(owner.accessToken())),
                java.util.Map.class);
        assertThat(updateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updateResponse.getBody().get("title")).isEqualTo("Haircut & Style");
        assertThat(updateResponse.getBody().get("durationMinutes")).isEqualTo(45);

        // A different owner can't touch it — 403, not silently allowed.
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "service-edit-other-owner@example.com");
        ResponseEntity<java.util.Map> forbidden = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())),
                java.util.Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deleteResponse = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<java.util.Map> afterDelete = restTemplate.getForEntity("/api/v1/services/" + serviceId,
                java.util.Map.class);
        assertThat(afterDelete.getBody().get("active")).isEqualTo(false);

        // Deactivating again (or a non-existent id) is a no-op, not an error.
        ResponseEntity<Void> deleteAgain = restTemplate.exchange("/api/v1/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // Deactivated services drop out of the default listing...
        assertThat(getServiceList(providerId, false)).isEmpty();
        // ...but are still visible (and reactivatable) with includeInactive=true.
        assertThat(getServiceList(providerId, true)).extracting(s -> s.get("id")).containsExactly(
                serviceId.toString());

        ResponseEntity<java.util.Map> reactivateResponse = restTemplate.exchange(
                "/api/v1/services/" + serviceId + "/reactivate", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(reactivateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reactivateResponse.getBody().get("active")).isEqualTo(true);
        assertThat(getServiceList(providerId, false)).extracting(s -> s.get("id")).containsExactly(
                serviceId.toString());
    }

    @Test
    void updatesASalonsNameAndLocationButOnlyTheOwnerCan() {
        Registered owner = TestAuth.registerOwner(restTemplate, "salon-edit-owner@example.com");
        UUID providerId = createProvider(owner, "Original Salon Name");

        var updateRequest = new UpdateProviderRequest("Renamed Salon", 43.25, 76.90);
        ResponseEntity<java.util.Map> updateResponse = restTemplate.exchange("/api/v1/providers/" + providerId,
                HttpMethod.PUT, new HttpEntity<>(updateRequest, TestAuth.authHeaders(owner.accessToken())),
                java.util.Map.class);
        assertThat(updateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updateResponse.getBody().get("name")).isEqualTo("Renamed Salon");
        assertThat(updateResponse.getBody().get("latitude")).isEqualTo(43.25);

        Registered otherOwner = TestAuth.registerOwner(restTemplate, "salon-edit-other-owner@example.com");
        ResponseEntity<java.util.Map> forbidden = restTemplate.exchange("/api/v1/providers/" + providerId,
                HttpMethod.PUT, new HttpEntity<>(updateRequest, TestAuth.authHeaders(otherOwner.accessToken())),
                java.util.Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void newProvidersStartPendingAndOnlyAnAdminCanModerateThem() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "moderation-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Moderation Salon " + runId);

        ResponseEntity<java.util.Map> created = restTemplate.getForEntity("/api/v1/providers/" + providerId,
                java.util.Map.class);
        assertThat(created.getBody().get("status")).isEqualTo("PENDING");

        // Neither the owner nor an unauthenticated caller can moderate.
        var approveRequest = new UpdateProviderStatusRequest(ProviderStatus.ACTIVE);
        ResponseEntity<java.util.Map> ownerAttempt = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(approveRequest, TestAuth.authHeaders(
                owner.accessToken())), java.util.Map.class);
        assertThat(ownerAttempt.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<java.util.Map> anonymousAttempt = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(approveRequest), java.util.Map.class);
        assertThat(anonymousAttempt.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // Admin approves it.
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "moderation-admin-" + runId + "@example.com");
        ResponseEntity<java.util.Map> approved = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(approveRequest, TestAuth.authHeaders(
                admin.accessToken())), java.util.Map.class);
        assertThat(approved.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(approved.getBody().get("status")).isEqualTo("ACTIVE");

        // Shows up in the PENDING filter before approval, not after.
        assertThat(getProviderIdsByStatus(ProviderStatus.PENDING)).doesNotContain(providerId.toString());
        assertThat(getProviderIdsByStatus(ProviderStatus.ACTIVE)).contains(providerId.toString());

        // Admin can also suspend it again.
        var suspendRequest = new UpdateProviderStatusRequest(ProviderStatus.SUSPENDED);
        ResponseEntity<java.util.Map> suspended = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(suspendRequest, TestAuth.authHeaders(
                admin.accessToken())), java.util.Map.class);
        assertThat(suspended.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(suspended.getBody().get("status")).isEqualTo("SUSPENDED");
    }

    private java.util.List<String> getProviderIdsByStatus(ProviderStatus status) {
        ResponseEntity<java.util.Map[]> response = restTemplate.getForEntity(
                "/api/v1/providers?status=" + status, java.util.Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return java.util.Arrays.stream(response.getBody()).map(p -> (String) p.get("id")).toList();
    }

    private java.util.List<java.util.Map> getServiceList(UUID providerId, boolean includeInactive) {
        ResponseEntity<java.util.Map[]> response = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/services?includeInactive=" + includeInactive,
                java.util.Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return java.util.List.of(response.getBody());
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<java.util.Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createService(Registered owner, UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        ResponseEntity<java.util.Map> response = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/services", HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(
                owner.accessToken())), java.util.Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
