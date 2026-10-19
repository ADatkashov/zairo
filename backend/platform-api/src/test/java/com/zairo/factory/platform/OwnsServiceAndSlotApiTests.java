package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import java.time.Instant;
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
 * {@code @OwnsService} / {@code @OwnsSlot}: ownership of a service or slot is ownership of its business,
 * decided before the method body runs; a missing id still falls through to the method's own 404 / 204.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class OwnsServiceAndSlotApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    private UUID createProvider(TestAuth.Registered owner) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), "Owned " + UUID.randomUUID(), "beauty"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        return UUID.fromString((String) response.getBody().get("id"));
    }

    private HttpStatus call(HttpMethod method, String url, Object body, String token) {
        ResponseEntity<String> response = restTemplate.exchange(url, method,
                new HttpEntity<>(body, token == null ? null : TestAuth.authHeaders(token)), String.class);
        return HttpStatus.valueOf(response.getStatusCode().value());
    }

    @Test
    void aSlotCanOnlyBeRemovedByItsBusinessOwner() {
        var owner = TestAuth.registerOwner(restTemplate, "slot-a-" + UUID.randomUUID() + "@example.com");
        var other = TestAuth.registerOwner(restTemplate, "slot-b-" + UUID.randomUUID() + "@example.com");
        UUID providerId = createProvider(owner);
        Instant start = Instant.now().plusSeconds(86_400);
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/providers/" + providerId + "/availability-slots",
                HttpMethod.POST, new HttpEntity<>(Map.of("startsAt", start.toString(),
                        "endsAt", start.plusSeconds(1800).toString()), TestAuth.authHeaders(owner.accessToken())),
                Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String slotUrl = "/api/v1/availability-slots/" + created.getBody().get("id");

        assertThat(call(HttpMethod.DELETE, slotUrl, null, null)).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(call(HttpMethod.DELETE, slotUrl, null, other.accessToken())).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(call(HttpMethod.DELETE, slotUrl, null, owner.accessToken())).isEqualTo(HttpStatus.NO_CONTENT);
        // Gone now: the method's own 404, not a refusal.
        assertThat(call(HttpMethod.DELETE, slotUrl, null, owner.accessToken())).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void aServiceCanOnlyBeChangedByItsBusinessOwner() {
        var owner = TestAuth.registerOwner(restTemplate, "svc-a-" + UUID.randomUUID() + "@example.com");
        var other = TestAuth.registerOwner(restTemplate, "svc-b-" + UUID.randomUUID() + "@example.com");
        UUID providerId = createProvider(owner);
        ResponseEntity<Map> created = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(Map.of("title", "Owned service", "durationMinutes", 30,
                        "price", 1000, "currency", "KZT"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        String url = "/api/v1/services/" + created.getBody().get("id");
        Map<String, Object> update = Map.of("title", "Renamed", "durationMinutes", 45, "price", 1200,
                "currency", "KZT");

        assertThat(call(HttpMethod.PUT, url, update, null)).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(call(HttpMethod.PUT, url, update, other.accessToken())).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(call(HttpMethod.DELETE, url, null, other.accessToken())).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(call(HttpMethod.POST, url + "/reactivate", null, other.accessToken()))
                .isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(call(HttpMethod.PATCH, url + "/catalog-link",
                Map.of("catalogServiceId", UUID.randomUUID()), other.accessToken()))
                .isEqualTo(HttpStatus.FORBIDDEN);

        assertThat(call(HttpMethod.PUT, url, update, owner.accessToken())).isEqualTo(HttpStatus.OK);
        assertThat(call(HttpMethod.DELETE, url, null, owner.accessToken())).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(call(HttpMethod.POST, url + "/reactivate", null, owner.accessToken())).isEqualTo(HttpStatus.OK);
    }

    @Test
    void anUnknownServiceFallsThroughToTheMethodsOwnAnswer() {
        var owner = TestAuth.registerOwner(restTemplate, "svc-c-" + UUID.randomUUID() + "@example.com");
        UUID missing = UUID.randomUUID();

        // The owner is past the check: reactivate says 404, the idempotent deactivate says 204.
        assertThat(call(HttpMethod.POST, "/api/v1/services/" + missing + "/reactivate", null, owner.accessToken()))
                .isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(call(HttpMethod.DELETE, "/api/v1/services/" + missing, null, owner.accessToken()))
                .isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(call(HttpMethod.POST, "/api/v1/services/" + missing + "/reactivate", null, null))
                .isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
