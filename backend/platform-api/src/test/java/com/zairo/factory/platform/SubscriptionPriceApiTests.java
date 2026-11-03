package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.subscriptions.SubscriptionPriceRepository;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
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
 * PRO's monthly price is set by PLATFORM_ADMIN, not by code: owners see and are charged the new price, support can
 * only read it, a bad value is refused, and the change is audit-logged.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestPayments.class})
class SubscriptionPriceApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Autowired
    private SubscriptionPriceRepository subscriptionPriceRepository;

    /** The other subscription tests expect the built-in price; leave the shared database as found. */
    @AfterEach
    void restoreBuiltInPrice() {
        subscriptionPriceRepository.deleteAll();
    }

    @Test
    void anAdminSetsThePriceInTengeAndOwnersSeeItAndAreChargedIt() {
        String runId = UUID.randomUUID().toString();
        var admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "price-admin-" + runId + "@factory.internal", PlatformRole.PLATFORM_ADMIN);

        ResponseEntity<Map> set = restTemplate.exchange("/api/v1/platform/subscription-price", HttpMethod.PUT,
                new HttpEntity<>(Map.of("monthlyPrice", 14900, "currency", "kzt"),
                        TestPlatformAuth.authHeaders(admin.accessToken())),
                Map.class);
        assertThat(set.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((Number) set.getBody().get("monthlyPrice")).doubleValue()).isEqualTo(14900.0);
        assertThat(set.getBody().get("currency")).isEqualTo("KZT");

        Registered owner = TestAuth.registerOwner(restTemplate, "price-owner-" + runId + "@example.com");
        Map<?, ?> subscription = restTemplate.exchange("/api/v1/subscriptions/me", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody();
        assertThat(((Number) subscription.get("proMonthlyPrice")).doubleValue()).isEqualTo(14900.0);
        assertThat(subscription.get("currency")).isEqualTo("KZT");

        // The upgrade charges exactly that price; the invoice history keeps the amount it was charged.
        restTemplate.exchange("/api/v1/subscriptions/upgrade", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        List<?> charges = restTemplate.exchange("/api/v1/subscriptions/me/charges", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class).getBody();
        assertThat(charges).isNotEmpty();
        Map<?, ?> charge = (Map<?, ?>) charges.get(0);
        assertThat(((Number) charge.get("amount")).doubleValue()).isEqualTo(14900.0);
        assertThat(charge.get("currency")).isEqualTo("KZT");

        // Audit-logged.
        ResponseEntity<Map> auditLog = restTemplate.exchange("/api/v1/platform/audit-log?size=100", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class);
        List<Map<String, Object>> entries = (List<Map<String, Object>>) auditLog.getBody().get("content");
        assertThat(entries).anySatisfy(entry -> assertThat(entry.get("action")).isEqualTo("SUBSCRIPTION_PRICE_SET"));
    }

    @Test
    void supportCanReadThePriceButNotChangeIt_andNonsenseIsRefused() {
        String runId = UUID.randomUUID().toString();
        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "price-support-" + runId + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        var admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "price-admin2-" + runId + "@factory.internal", PlatformRole.PLATFORM_ADMIN);

        ResponseEntity<Map> read = restTemplate.exchange("/api/v1/platform/subscription-price", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())), Map.class);
        assertThat(read.getStatusCode()).isEqualTo(HttpStatus.OK);
        // Nothing set yet: the built-in price still applies.
        assertThat(((Number) read.getBody().get("monthlyPrice")).doubleValue()).isEqualTo(29.0);

        ResponseEntity<Map> forbidden = restTemplate.exchange("/api/v1/platform/subscription-price", HttpMethod.PUT,
                new HttpEntity<>(Map.of("monthlyPrice", 100, "currency", "KZT"),
                        TestPlatformAuth.authHeaders(support.accessToken())),
                Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        for (Map<String, Object> bad : List.<Map<String, Object>>of(Map.of("monthlyPrice", 0, "currency", "KZT"),
                Map.of("monthlyPrice", -5, "currency", "KZT"), Map.of("monthlyPrice", 100, "currency", "TENGE"),
                Map.of("monthlyPrice", 100))) {
            ResponseEntity<Map> refused = restTemplate.exchange("/api/v1/platform/subscription-price",
                    HttpMethod.PUT, new HttpEntity<>(bad, TestPlatformAuth.authHeaders(admin.accessToken())),
                    Map.class);
            assertThat(refused.getStatusCode()).as(bad.toString()).isEqualTo(HttpStatus.BAD_REQUEST);
        }
    }
}
