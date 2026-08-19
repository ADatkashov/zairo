package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserRole;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
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
}
