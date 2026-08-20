package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.UpdateServiceRequest;
import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserRole;
import java.math.BigDecimal;
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

    @Test
    void createsOwnerThenProviderThenService() {
        var ownerRequest = new CreateUserRequest("owner@example.com", "+1000000000", "Salon Owner",
                UserRole.PROVIDER_OWNER);
        ResponseEntity<Object> ownerResponse = restTemplate.postForEntity("/api/v1/users", ownerRequest,
                Object.class);
        assertThat(ownerResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        var ownerId = java.util.UUID.fromString(
                ((java.util.Map<?, ?>) ownerResponse.getBody()).get("id").toString());

        var providerRequest = new CreateProviderRequest(ownerId, "Best Beauty Salon", "beauty");
        ResponseEntity<java.util.Map> providerResponse = restTemplate.postForEntity("/api/v1/providers",
                providerRequest, java.util.Map.class);
        assertThat(providerResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var providerId = providerResponse.getBody().get("id").toString();

        var serviceRequest = new CreateServiceRequest("Haircut", 45, new BigDecimal("30.00"), "USD");
        ResponseEntity<Object> serviceResponse = restTemplate.postForEntity(
                "/api/v1/providers/" + providerId + "/services", serviceRequest, Object.class);
        assertThat(serviceResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<Object[]> listResponse = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/services", Object[].class);
        assertThat(listResponse.getBody()).hasSize(1);
    }

    @Test
    void updatesThenDeactivatesAService() {
        Registered owner = registerOwner("service-edit-owner@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Service Edit Salon", "beauty");
        var providerId = java.util.UUID.fromString(((java.util.Map<?, ?>) restTemplate
                .postForEntity("/api/v1/providers", providerRequest, java.util.Map.class).getBody()).get("id")
                .toString());

        var createRequest = new CreateServiceRequest("Haircut", 30, new BigDecimal("25.00"), "USD");
        var serviceId = java.util.UUID.fromString(((java.util.Map<?, ?>) restTemplate
                .postForEntity("/api/v1/providers/" + providerId + "/services", createRequest, java.util.Map.class)
                .getBody()).get("id").toString());

        var updateRequest = new UpdateServiceRequest("Haircut & Style", 45, new BigDecimal("35.00"), "USD");
        ResponseEntity<java.util.Map> updateResponse = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.PUT, new HttpEntity<>(updateRequest, authHeaders(owner.accessToken())),
                java.util.Map.class);
        assertThat(updateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updateResponse.getBody().get("title")).isEqualTo("Haircut & Style");
        assertThat(updateResponse.getBody().get("durationMinutes")).isEqualTo(45);

        // A different owner can't touch it — 403, not silently allowed.
        Registered otherOwner = registerOwner("service-edit-other-owner@example.com");
        ResponseEntity<java.util.Map> forbidden = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.DELETE, new HttpEntity<>(null, authHeaders(otherOwner.accessToken())),
                java.util.Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deleteResponse = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.DELETE, new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<java.util.Map> afterDelete = restTemplate.getForEntity("/api/v1/services/" + serviceId,
                java.util.Map.class);
        assertThat(afterDelete.getBody().get("active")).isEqualTo(false);

        // Deactivating again (or a non-existent id) is a no-op, not an error.
        ResponseEntity<Void> deleteAgain = restTemplate.exchange("/api/v1/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }

    private record Registered(UUID userId, String accessToken) {
    }

    private Registered registerOwner(String email) {
        var request = new RegisterRequest(email, "password123", "Registered Owner", "+1000000002",
                UserRole.PROVIDER_OWNER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/auth/register", request, Map.class).getBody();
        UUID userId = UUID.fromString(((Map<?, ?>) body.get("user")).get("id").toString());
        return new Registered(userId, body.get("accessToken").toString());
    }

    private HttpHeaders authHeaders(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        return headers;
    }
}
