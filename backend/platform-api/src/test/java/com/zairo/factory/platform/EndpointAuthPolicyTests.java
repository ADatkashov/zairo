package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.security.RequireAuthenticationInterceptor;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

/**
 * Default-deny policy for the whole HTTP API. Every {@code /api} endpoint is
 * either documented as needing a bearer token ({@code @SecurityRequirement}, which
 * {@link RequireAuthenticationInterceptor} enforces with a 401 before anything
 * else) or is listed in {@link #PUBLIC} on purpose. Adding an endpoint without
 * the annotation fails this test until someone decides, in review, that it is
 * public and adds it here.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class EndpointAuthPolicyTests {

    /**
     * Intentionally public: sign-in/registration/recovery flows (they hand out
     * the credentials), and read-only browsing that customers use before they
     * have an account (search, catalogue, providers, staff, reviews, slots).
     * Format: {@code METHOD pattern}.
     */
    static final Set<String> PUBLIC = Set.of(
            "GET /api/v1/ads/banners",
            "GET /api/v1/auth/phone/sms-mode",
            "GET /api/v1/auto/mechanics/{mechanicId}",
            "GET /api/v1/auto/mechanics/{mechanicId}/services",
            "GET /api/v1/auto/providers/{providerId}/mechanics",
            "GET /api/v1/beauty/masters/{masterId}",
            "GET /api/v1/beauty/masters/{masterId}/portfolio",
            "GET /api/v1/beauty/masters/{masterId}/services",
            "GET /api/v1/beauty/providers/{providerId}/masters",
            "GET /api/v1/bookings/{bookingId}/reviews",
            "GET /api/v1/business-types/{id}/services",
            "GET /api/v1/business-types/{id}/subspheres",
            "GET /api/v1/categories",
            "GET /api/v1/categories/{id}/business-types",
            "GET /api/v1/cities",
            "GET /api/v1/cities/country/{countryCode}",
            "GET /api/v1/cities/country/{countryCode}/active",
            "GET /api/v1/cities/nearest",
            "GET /api/v1/cities/{code}",
            "GET /api/v1/cleaning/cleaners/{cleanerId}",
            "GET /api/v1/cleaning/cleaners/{cleanerId}/services",
            "GET /api/v1/cleaning/providers/{providerId}/cleaners",
            "GET /api/v1/countries",
            "GET /api/v1/countries/{code}",
            "GET /api/v1/payment-settings/public",
            "GET /api/v1/providers",
            "GET /api/v1/providers/{id}",
            "GET /api/v1/providers/{providerId}/availability-slots",
            "GET /api/v1/providers/{providerId}/availability/any",
            "GET /api/v1/providers/{providerId}/reviews/public",
            "GET /api/v1/providers/{providerId}/reviews/summary",
            "GET /api/v1/providers/{providerId}/services",
            "GET /api/v1/providers/{providerId}/services/{serviceId}/worker-prices",
            "GET /api/v1/providers/{providerId}/staff",
            "GET /api/v1/providers/{providerId}/workers/{workerId}/availability",
            "GET /api/v1/providers/{providerId}/workforce-settings",
            "GET /api/v1/search/providers",
            "GET /api/v1/services/{id}",
            "GET /api/v1/staff/{staffId}",
            "GET /api/v1/staff/{staffId}/services",
            "GET /api/v1/subspheres/{id}/services",
            "GET /api/v1/uploads/{key}",
            "GET /api/v1/users/{ownerUserId}/providers",
            "GET /api/v1/workers/top",
            "GET /api/v1/workers/{workerId}",
            "POST /api/v1/auth/apple",
            "POST /api/v1/auth/facebook",
            "POST /api/v1/auth/forgot-password",
            "POST /api/v1/auth/google",
            "POST /api/v1/auth/identities/link-with-password",
            "POST /api/v1/auth/login",
            "POST /api/v1/auth/phone/login",
            "POST /api/v1/auth/phone/register",
            "POST /api/v1/auth/phone/request-otp",
            "POST /api/v1/auth/phone/reset-password",
            "POST /api/v1/auth/phone/status",
            "POST /api/v1/auth/phone/verify-otp",
            "POST /api/v1/auth/refresh",
            "POST /api/v1/auth/register",
            "POST /api/v1/auth/reset-password",
            "POST /api/v1/platform/auth/login");

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    @Qualifier("requestMappingHandlerMapping")
    private RequestMappingHandlerMapping handlerMapping;

    private record Endpoint(String method, String pattern, HandlerMethod handler, boolean multipart) {
        String key() {
            return method + " " + pattern;
        }

        boolean secured() {
            return RequireAuthenticationInterceptor.requiresAuthentication(handler);
        }
    }

    private List<Endpoint> apiEndpoints() {
        List<Endpoint> result = new ArrayList<>();
        for (Map.Entry<RequestMappingInfo, HandlerMethod> entry : handlerMapping.getHandlerMethods().entrySet()) {
            var patterns = entry.getKey().getPathPatternsCondition();
            if (patterns == null) {
                continue;
            }
            for (String pattern : patterns.getPatternValues()) {
                if (!pattern.startsWith("/api/")) {
                    continue;
                }
                for (RequestMethod method : entry.getKey().getMethodsCondition().getMethods()) {
                    boolean multipart = entry.getKey().getConsumesCondition().getConsumableMediaTypes().stream()
                            .anyMatch(type -> type.isCompatibleWith(MediaType.MULTIPART_FORM_DATA));
                    result.add(new Endpoint(method.name(), pattern, entry.getValue(), multipart));
                }
            }
        }
        return result;
    }

    @Test
    void everyEndpointIsEitherSecuredOrDeliberatelyPublic() {
        Set<String> unclassified = new TreeSet<>();
        for (Endpoint endpoint : apiEndpoints()) {
            if (!endpoint.secured() && !PUBLIC.contains(endpoint.key())) {
                unclassified.add(endpoint.key() + "  (" + endpoint.handler().getShortLogMessage() + ")");
            }
        }

        assertThat(unclassified)
                .as("Endpoints with neither @SecurityRequirement nor an entry in PUBLIC — "
                        + "protect them, or add them to PUBLIC if they are meant to be open")
                .isEmpty();
    }

    @Test
    void thePublicListHasNoStaleOrSecuredEntries() {
        Set<String> secured = new TreeSet<>();
        Set<String> existing = new TreeSet<>();
        for (Endpoint endpoint : apiEndpoints()) {
            existing.add(endpoint.key());
            if (endpoint.secured()) {
                secured.add(endpoint.key());
            }
        }

        assertThat(PUBLIC).as("PUBLIC entries that no longer exist").isSubsetOf(existing);
        assertThat(PUBLIC).as("PUBLIC entries that are actually secured").doesNotContainAnyElementsOf(secured);
    }

    @Test
    void everySecuredEndpointAnswers401WithoutATokenBeforeAnythingElse() {
        List<String> wrong = new ArrayList<>();
        for (Endpoint endpoint : apiEndpoints()) {
            if (!endpoint.secured()) {
                continue;
            }
            String path = endpoint.pattern().replaceAll("\\{[^/}]+}", "00000000-0000-0000-0000-000000000001");
            HttpHeaders headers = new HttpHeaders();
            // A wrong body would be a 400, an unknown id a 404, a wrong content type a 415 —
            // none of them may come before the 401.
            boolean hasBody = !endpoint.method().equals("GET") && !endpoint.method().equals("DELETE");
            String body = null;
            if (endpoint.multipart()) {
                headers.set(HttpHeaders.CONTENT_TYPE, "multipart/form-data; boundary=x");
                body = "--x--\r\n";
            } else if (hasBody) {
                headers.setContentType(MediaType.APPLICATION_JSON);
                body = "{}";
            }
            int status = restTemplate.exchange(path, HttpMethod.valueOf(endpoint.method()),
                    new HttpEntity<>(body, headers), String.class).getStatusCode().value();
            if (status != 401) {
                wrong.add(status + " " + endpoint.key());
            }
        }

        assertThat(wrong).as("Secured endpoints that did not answer 401 to an anonymous request").isEmpty();
    }

    @Test
    void aGarbageTokenIsTreatedLikeNoToken() {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth("not-a-real-token");

        int status = restTemplate.exchange("/api/v1/users/00000000-0000-0000-0000-000000000001/bookings",
                HttpMethod.GET, new HttpEntity<>(headers), String.class).getStatusCode().value();

        assertThat(status).isEqualTo(401);
    }
}
