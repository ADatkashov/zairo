package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
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

/** Against a real Postgres (Testcontainers) — the platform-wide dashboard's live-query counts move with real data. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class PlatformInsightsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void requiresAuthenticationAndCountsAFreshlyPaidBooking() {
        ResponseEntity<Map> unauthenticated = restTemplate.getForEntity("/api/v1/platform/dashboard", Map.class);
        assertThat(unauthenticated.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "dashboard-support-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);

        Map<?, ?> before = restTemplate.exchange("/api/v1/platform/dashboard", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())), Map.class).getBody();
        long usersBefore = ((Number) ((Map<?, ?>) before.get("users")).get("total")).longValue();
        long paymentsSucceededBefore = ((Number) ((Map<?, ?>) before.get("payments")).get("succeeded")).longValue();

        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "dashboard-cust-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "dashboard-owner-" + runId + "@example.com");

        var providerRequest = new CreateProviderRequest(owner.userId(), "Dashboard Salon " + runId, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        var serviceRequest = new CreateServiceRequest("Dashboard Service", 30, new BigDecimal("15.00"), "USD");
        UUID serviceId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class).getBody().get("id").toString());
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId
                + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("15.00"));
        UUID bookingId = UUID.fromString(restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody()
                .get("id").toString());
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);

        Map<?, ?> after = restTemplate.exchange("/api/v1/platform/dashboard", HttpMethod.GET,
                new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())), Map.class).getBody();
        long usersAfter = ((Number) ((Map<?, ?>) after.get("users")).get("total")).longValue();
        long paymentsSucceededAfter = ((Number) ((Map<?, ?>) after.get("payments")).get("succeeded")).longValue();
        long bookingsToday = ((Number) ((Map<?, ?>) after.get("bookings")).get("today")).longValue();

        // Two new accounts registered (customer + owner).
        assertThat(usersAfter).isEqualTo(usersBefore + 2);
        assertThat(paymentsSucceededAfter).isEqualTo(paymentsSucceededBefore + 1);
        assertThat(bookingsToday).isGreaterThanOrEqualTo(1);
        assertThat(after.get("revenue")).isNotNull();
    }

    @Test
    void trendsRequireAuthAndReturnAZeroFilledWindowOldestFirst() {
        assertThat(restTemplate.getForEntity("/api/v1/platform/dashboard/trends", Map.class).getStatusCode())
                .isEqualTo(HttpStatus.UNAUTHORIZED);

        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "trends-support-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        HttpEntity<Void> auth = new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken()));

        Map<?, ?> week = restTemplate.exchange("/api/v1/platform/dashboard/trends?days=7", HttpMethod.GET, auth,
                Map.class).getBody();
        java.util.List<?> days = (java.util.List<?>) week.get("bookingsCreated");
        assertThat(days).hasSize(7);
        assertThat(((Map<?, ?>) days.get(6)).get("date")).isEqualTo(java.time.LocalDate.now(java.time.ZoneOffset.UTC).toString());
        assertThat(((Map<?, ?>) days.get(0)).get("date").toString())
                .isLessThan(((Map<?, ?>) days.get(6)).get("date").toString());

        // An out-of-range window is clamped, not rejected.
        Map<?, ?> huge = restTemplate.exchange("/api/v1/platform/dashboard/trends?days=500", HttpMethod.GET, auth,
                Map.class).getBody();
        assertThat((java.util.List<?>) huge.get("bookingsCreated")).hasSize(31);
        Map<?, ?> zero = restTemplate.exchange("/api/v1/platform/dashboard/trends?days=0", HttpMethod.GET, auth,
                Map.class).getBody();
        assertThat((java.util.List<?>) zero.get("bookingsCreated")).hasSize(1);
    }

    @Test
    void reportRequiresAuthAndReturnsZeroFilledSeriesForTheWindow() {
        assertThat(restTemplate.getForEntity("/api/v1/platform/reports", Map.class).getStatusCode())
                .isEqualTo(HttpStatus.UNAUTHORIZED);

        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "report-support-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        HttpEntity<Void> auth = new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken()));

        Map<?, ?> report = restTemplate.exchange("/api/v1/platform/reports?days=7", HttpMethod.GET, auth, Map.class)
                .getBody();
        assertThat((java.util.List<?>) report.get("bookingsCreated")).hasSize(7);
        assertThat((java.util.List<?>) report.get("commissionByDay")).hasSize(7);
        assertThat((java.util.List<?>) report.get("subscriptionRevenueByDay")).hasSize(7);
        assertThat(report.get("to")).isEqualTo(java.time.LocalDate.now(java.time.ZoneOffset.UTC).toString());
        assertThat(report.get("bookingsByStatus")).isNotNull();

        Map<?, ?> defaulted = restTemplate.exchange("/api/v1/platform/reports", HttpMethod.GET, auth, Map.class)
                .getBody();
        assertThat((java.util.List<?>) defaulted.get("bookingsCreated")).hasSize(30);
        Map<?, ?> capped = restTemplate.exchange("/api/v1/platform/reports?days=1000", HttpMethod.GET, auth, Map.class)
                .getBody();
        assertThat((java.util.List<?>) capped.get("bookingsCreated")).hasSize(90);
    }

    @Test
    void aFreshBookingShowsUpInTodaysBucketOfTheReport() {
        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "report-bucket-" + UUID.randomUUID() + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        HttpEntity<Void> auth = new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken()));
        long before = todaysBookings(auth);

        String runId = UUID.randomUUID().toString();
        Registered customer = TestAuth.registerCustomer(restTemplate, "report-cust-" + runId + "@example.com");
        Registered owner = TestAuth.registerOwner(restTemplate, "report-owner-" + runId + "@example.com");
        var providerRequest = new CreateProviderRequest(owner.userId(), "Report Salon " + runId, "beauty");
        UUID providerId = UUID.fromString(restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(providerRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        var serviceRequest = new CreateServiceRequest("Report Service", 30, new BigDecimal("15.00"), "USD");
        UUID serviceId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(owner.accessToken())),
                Map.class).getBody().get("id").toString());
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var slotRequest = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        UUID slotId = UUID.fromString(restTemplate.exchange("/api/v1/providers/" + providerId
                + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(slotRequest, TestAuth.authHeaders(owner.accessToken())), Map.class).getBody()
                .get("id").toString());
        var bookingRequest = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal("15.00"));
        restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class);

        assertThat(todaysBookings(auth)).isEqualTo(before + 1);
    }

    private long todaysBookings(HttpEntity<Void> auth) {
        Map<?, ?> report = restTemplate.exchange("/api/v1/platform/reports?days=3", HttpMethod.GET, auth, Map.class)
                .getBody();
        java.util.List<?> days = (java.util.List<?>) report.get("bookingsCreated");
        return ((Number) ((Map<?, ?>) days.get(days.size() - 1)).get("count")).longValue();
    }
}
