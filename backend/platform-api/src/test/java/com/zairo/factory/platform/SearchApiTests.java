package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.users.UserRepository;
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
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
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

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Test
    void pendingProvidersAreInvisibleToSearchUntilAnAdminApprovesThem() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-mod-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "mod-search-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Unapproved Salon " + runId, vertical);
        createService(owner, providerId, "Cut", new BigDecimal("10.00"));

        assertThat(search(vertical, null)).isEmpty();

        approve(providerId);

        assertThat(search(vertical, null)).extracting(r -> r.get("id")).containsExactly(providerId.toString());
    }

    @Test
    void filtersByVerticalAndQueryAndRanksByAvailabilityThenPrice() {
        String runId = UUID.randomUUID().toString();
        String verticalBeauty = "beauty-" + runId;
        String verticalAuto = "auto-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "search-owner-" + runId + "@example.com");

        UUID providerA = createProvider(owner, "Hair Studio A " + runId, verticalBeauty);
        createService(owner, providerA, "Haircut", new BigDecimal("30.00"));
        createOpenSlot(owner, providerA);
        approve(providerA);

        UUID providerB = createProvider(owner, "Beauty Bar B " + runId, verticalBeauty);
        createService(owner, providerB, "Massage", new BigDecimal("20.00"));
        // no availability slot for B
        approve(providerB);

        UUID providerC = createProvider(owner, "Quick Lube C " + runId, verticalAuto);
        createService(owner, providerC, "Oil change", new BigDecimal("15.00"));
        // no availability slot for C
        approve(providerC);

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

    @Test
    void ranksByDistanceWhenTheCallerSuppliesItsLocation() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-dist-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "dist-owner-" + runId + "@example.com");

        // Almaty city center as the search origin.
        double originLat = 43.2389;
        double originLng = 76.8897;

        // Near: a few km away.
        UUID providerNear = createProvider(owner, "Near Salon " + runId, vertical, 43.25, 76.90);
        createService(owner, providerNear, "Cut", new BigDecimal("20.00"));
        createOpenSlot(owner, providerNear);
        approve(providerNear);

        // Far: a different city entirely (Astana), hundreds of km away.
        UUID providerFar = createProvider(owner, "Far Salon " + runId, vertical, 51.1694, 71.4491);
        createService(owner, providerFar, "Cut", new BigDecimal("20.00"));
        createOpenSlot(owner, providerFar);
        approve(providerFar);

        List<Map> results = search(vertical, null, originLat, originLng);
        assertThat(results).extracting(r -> r.get("id")).containsExactly(providerNear.toString(),
                providerFar.toString());
        double nearDistance = ((Number) results.get(0).get("distanceKm")).doubleValue();
        double farDistance = ((Number) results.get(1).get("distanceKm")).doubleValue();
        assertThat(nearDistance).isLessThan(farDistance);
    }

    private List<Map> search(String vertical, String q) {
        return search(vertical, q, null, null);
    }

    private List<Map> search(String vertical, String q, Double lat, Double lng) {
        StringBuilder url = new StringBuilder("/api/v1/search/providers?");
        if (vertical != null) {
            url.append("vertical=").append(vertical).append("&");
        }
        if (q != null) {
            url.append("q=").append(q).append("&");
        }
        if (lat != null && lng != null) {
            url.append("lat=").append(lat).append("&lng=").append(lng);
        }
        ResponseEntity<Map[]> response = restTemplate.getForEntity(url.toString(), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private UUID createProvider(Registered owner, String name, String vertical) {
        var request = new CreateProviderRequest(owner.userId(), name, vertical);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createProvider(Registered owner, String name, String vertical, double latitude, double longitude) {
        var request = new CreateProviderRequest(owner.userId(), name, vertical, latitude, longitude);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private void createService(Registered owner, UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    /** Search only ever surfaces ACTIVE providers — every provider a test wants findable must go through this. */
    private void approve(UUID providerId) {
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "search-admin-" + UUID.randomUUID() + "@example.com");
        var request = new UpdateProviderStatusRequest(ProviderStatus.ACTIVE);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/status",
                HttpMethod.PATCH, new HttpEntity<>(request, TestAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private void createOpenSlot(Registered owner, UUID providerId) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var request = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }
}
