package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserDtos.CreateUserRequest;
import com.zairo.factory.users.UserRole;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Against a real Postgres (Testcontainers): verifies vertical filtering,
 * text search across provider name / service title, and the deterministic
 * ranking (open availability first, then cheapest price).
 *
 * Spring's test context cache reuses the same ApplicationContext (and thus
 * the same Testcontainers Postgres + accumulated data) across every test
 * class with this exact same annotation set — ProviderApiTests,
 * BookingApiTests, ReviewApiTests all match. So this test uses a
 * random per-run vertical value (no collision with other tests' fixed
 * "beauty"/"auto" verticals) and containsSubsequence instead of
 * containsExactly for the unfiltered "all providers" case, since other
 * tests' providers are legitimately mixed in.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class SearchApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void filtersByVerticalAndQueryAndRanksByAvailabilityThenPrice() {
        String runId = UUID.randomUUID().toString();
        String verticalBeauty = "beauty-" + runId;
        String verticalAuto = "auto-" + runId;
        UUID ownerId = createUser("search-owner-" + runId + "@example.com", "Search Owner");

        UUID providerA = createProvider(ownerId, "Hair Studio A " + runId, verticalBeauty);
        createService(providerA, "Haircut", new BigDecimal("30.00"));
        createOpenSlot(providerA);

        UUID providerB = createProvider(ownerId, "Beauty Bar B " + runId, verticalBeauty);
        createService(providerB, "Massage", new BigDecimal("20.00"));
        // no availability slot for B

        UUID providerC = createProvider(ownerId, "Quick Lube C " + runId, verticalAuto);
        createService(providerC, "Oil change", new BigDecimal("15.00"));
        // no availability slot for C

        List<Map> beautyResults = search(verticalBeauty, null);
        assertThat(beautyResults).extracting(r -> r.get("id"))
                .containsExactlyInAnyOrder(providerA.toString(), providerB.toString());
        // A has open availability, so it ranks first despite being pricier.
        assertThat(beautyResults.get(0).get("id")).isEqualTo(providerA.toString());

        List<Map> hairQuery = search(verticalBeauty, "hair");
        assertThat(hairQuery).extracting(r -> r.get("id")).containsExactly(providerA.toString());

        List<Map> allResults = search(null, null);
        assertThat(allResults).extracting(r -> r.get("id")).containsSubsequence(providerA.toString(),
                providerC.toString(), providerB.toString());
    }

    private List<Map> search(String vertical, String q) {
        StringBuilder url = new StringBuilder("/api/v1/search/providers?");
        if (vertical != null) {
            url.append("vertical=").append(vertical).append("&");
        }
        if (q != null) {
            url.append("q=").append(q);
        }
        ResponseEntity<Map[]> response = restTemplate.getForEntity(url.toString(), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private UUID createProvider(UUID ownerId, String name, String vertical) {
        var request = new CreateProviderRequest(ownerId, name, vertical);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/providers", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }

    private void createService(UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        restTemplate.postForEntity("/api/v1/providers/" + providerId + "/services", request, Map.class);
    }

    private void createOpenSlot(UUID providerId) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var request = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        restTemplate.postForEntity("/api/v1/providers/" + providerId + "/availability-slots", request, Map.class);
    }

    private UUID createUser(String email, String displayName) {
        var request = new CreateUserRequest(email, "+1000000000", displayName, UserRole.PROVIDER_OWNER);
        Map<?, ?> body = restTemplate.postForEntity("/api/v1/users", request, Map.class).getBody();
        return UUID.fromString(body.get("id").toString());
    }
}
