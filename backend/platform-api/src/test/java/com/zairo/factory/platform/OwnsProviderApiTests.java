package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.OwnsProvider;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

/**
 * {@code @OwnsProvider} (method security) answers exactly what the imperative
 * {@code ProviderOwnership.requireOwner} used to: 401 / 404 / 403 / allowed.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class OwnsProviderApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdmins;

    @Autowired
    @Qualifier("requestMappingHandlerMapping")
    private RequestMappingHandlerMapping handlerMapping;

    private UUID createProvider(TestAuth.Registered owner) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), "Owned " + UUID.randomUUID(), "beauty"),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString((String) response.getBody().get("id"));
    }

    private HttpStatus settings(UUID providerId, String token) {
        ResponseEntity<String> response = restTemplate.exchange("/api/v1/payment-settings?providerId=" + providerId,
                HttpMethod.GET, new HttpEntity<>(token == null ? null : TestAuth.authHeaders(token)), String.class);
        return HttpStatus.valueOf(response.getStatusCode().value());
    }

    @Test
    void theOwnerPassesAnotherOwnerIsForbiddenAnUnknownProviderIs404() {
        var owner = TestAuth.registerOwner(restTemplate, "owns-a-" + UUID.randomUUID() + "@example.com");
        var other = TestAuth.registerOwner(restTemplate, "owns-b-" + UUID.randomUUID() + "@example.com");
        UUID providerId = createProvider(owner);

        assertThat(settings(providerId, owner.accessToken())).isEqualTo(HttpStatus.OK);
        assertThat(settings(providerId, other.accessToken())).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(settings(UUID.randomUUID(), owner.accessToken())).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(settings(providerId, null)).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void aPlatformTokenIsNeverAnOwner() {
        var owner = TestAuth.registerOwner(restTemplate, "owns-c-" + UUID.randomUUID() + "@example.com");
        UUID providerId = createProvider(owner);
        String admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdmins,
                "owns-admin-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_ADMIN).accessToken();

        assertThat(settings(providerId, admin)).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    /** The SpEL in {@code @OwnsProvider} reads {@code #providerId}: every use must have that UUID parameter. */
    @Test
    void everyOwnsProviderEndpointHasAProviderIdUuidParameter() {
        List<String> wrong = new ArrayList<>();
        int annotated = 0;
        for (HandlerMethod handler : handlerMapping.getHandlerMethods().values()) {
            Method method = handler.getMethod();
            if (!method.isAnnotationPresent(OwnsProvider.class)) {
                continue;
            }
            annotated++;
            boolean ok = java.util.Arrays.stream(method.getParameters())
                    .anyMatch(p -> p.getName().equals("providerId") && p.getType() == UUID.class);
            if (!ok) {
                wrong.add(method.toString());
            }
        }

        assertThat(annotated).as("annotated endpoints found").isGreaterThan(40);
        assertThat(wrong).isEmpty();
    }

    /** {@code @OwnsService} / {@code @OwnsSlot} read {@code #id}: same guard against a renamed parameter. */
    @Test
    void everyOwnsServiceAndOwnsSlotEndpointHasAnIdUuidParameter() {
        List<String> wrong = new ArrayList<>();
        int annotated = 0;
        for (HandlerMethod handler : handlerMapping.getHandlerMethods().values()) {
            Method method = handler.getMethod();
            boolean entityOwnership = java.util.Arrays.stream(method.getAnnotations()).anyMatch(a ->
                    a.annotationType().getSimpleName().equals("OwnsService")
                            || a.annotationType().getSimpleName().equals("OwnsSlot"));
            if (!entityOwnership) {
                continue;
            }
            annotated++;
            if (java.util.Arrays.stream(method.getParameters())
                    .noneMatch(p -> p.getName().equals("id") && p.getType() == UUID.class)) {
                wrong.add(method.toString());
            }
        }

        assertThat(annotated).as("annotated endpoints found").isEqualTo(5);
        assertThat(wrong).isEmpty();
    }
}
