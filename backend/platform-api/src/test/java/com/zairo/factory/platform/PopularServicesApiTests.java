package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
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
 * Against a real Postgres (Testcontainers) -- "popular services" from real bookings. The context (and database) is
 * shared with other test classes, so every service here carries a random per-run suffix and is looked up by it.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class PopularServicesApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Test
    void ranksServicesByKeptBookingsAcrossBusinessesAndIgnoresUnpaidAndUnapprovedOnes() {
        String run = UUID.randomUUID().toString().substring(0, 8);
        Registered ownerA = TestAuth.registerOwner(restTemplate, "popular-a-" + run + "@example.com");
        Registered ownerB = TestAuth.registerOwner(restTemplate, "popular-b-" + run + "@example.com");
        Registered ownerHidden = TestAuth.registerOwner(restTemplate, "popular-h-" + run + "@example.com");
        Registered customer = TestAuth.registerCustomer(restTemplate, "popular-c-" + run + "@example.com");
        UUID providerA = createProvider(ownerA, "Popular A " + run);
        UUID providerB = createProvider(ownerB, "Popular B " + run);
        UUID providerHidden = createProvider(ownerHidden, "Popular Hidden " + run);
        approve(providerA);
        approve(providerB);
        // providerHidden stays PENDING: it is not discoverable, so neither is what it sells.

        String waxing = "Waxing " + run;
        String rare = "Rare " + run;
        String cancelled = "Cancelled " + run;
        String hidden = "Hidden " + run;
        UUID waxingA = createService(ownerA, providerA, waxing, new BigDecimal("30.00"));
        UUID waxingB = createService(ownerB, providerB, waxing.toLowerCase(), new BigDecimal("20.00"));
        UUID rareA = createService(ownerA, providerA, rare, new BigDecimal("50.00"));
        UUID cancelledA = createService(ownerA, providerA, cancelled, new BigDecimal("10.00"));
        UUID hiddenService = createService(ownerHidden, providerHidden, hidden, new BigDecimal("15.00"));

        book(ownerA, customer, providerA, waxingA, "30.00", 1);
        book(ownerA, customer, providerA, waxingA, "30.00", 2);
        book(ownerB, customer, providerB, waxingB, "20.00", 1);
        book(ownerA, customer, providerA, rareA, "50.00", 3);
        cancel(customer, book(ownerA, customer, providerA, cancelledA, "10.00", 4));
        book(ownerHidden, customer, providerHidden, hiddenService, "15.00", 1);

        // Public: no authentication needed.
        ResponseEntity<List> response = restTemplate.getForEntity("/api/v1/search/popular-services?limit=20", List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<Map<String, Object>> popular = response.getBody();

        Map<String, Object> waxingRow = byTitleIgnoringCase(popular, waxing);
        assertThat(waxingRow).isNotNull();
        assertThat(((Number) waxingRow.get("bookings")).longValue()).isEqualTo(3);
        assertThat(((Number) waxingRow.get("providerCount")).intValue()).isEqualTo(2);
        assertThat(new BigDecimal(waxingRow.get("minPrice").toString())).isEqualByComparingTo("20.00");
        assertThat(waxingRow.get("currency")).isEqualTo("USD");

        Map<String, Object> rareRow = byTitleIgnoringCase(popular, rare);
        assertThat(rareRow).isNotNull();
        assertThat(((Number) rareRow.get("bookings")).longValue()).isEqualTo(1);
        assertThat(popular.indexOf(waxingRow)).isLessThan(popular.indexOf(rareRow));

        assertThat(byTitleIgnoringCase(popular, cancelled)).as("a cancelled booking is not a kept booking").isNull();
        assertThat(byTitleIgnoringCase(popular, hidden)).as("a PENDING business is not discoverable").isNull();

        ResponseEntity<List> capped = restTemplate.getForEntity("/api/v1/search/popular-services?limit=1", List.class);
        assertThat(capped.getBody()).hasSize(1);
        ResponseEntity<List> otherCity = restTemplate.getForEntity(
                "/api/v1/search/popular-services?limit=20&city=no-such-city-" + run, List.class);
        assertThat(otherCity.getBody()).isEmpty();
    }

    private static Map<String, Object> byTitleIgnoringCase(List<Map<String, Object>> rows, String title) {
        return rows.stream().filter(r -> title.equalsIgnoreCase(r.get("title").toString())).findFirst().orElse(null);
    }

    /** One booking in its own slot (the default policy needs no deposit, so it is CONFIRMED at once); returns its id. */
    private UUID book(Registered owner, Registered customer, UUID providerId, UUID serviceId, String price,
            int dayOffset) {
        Instant start = Instant.now().plus(dayOffset, ChronoUnit.DAYS).plus(2, ChronoUnit.HOURS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        var request = new CreateBookingRequest(customer.userId(), serviceId, slotId, new BigDecimal(price));
        ResponseEntity<Map> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(booking.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(booking.getBody().get("id").toString());
    }

    private void cancel(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private void approve(UUID providerId) {
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "popular-admin-" + UUID.randomUUID() + "@example.com");
        var request = new UpdateProviderStatusRequest(ProviderStatus.ACTIVE);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/status",
                HttpMethod.PATCH, new HttpEntity<>(request, TestAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createService(Registered owner, UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createSlot(Registered owner, UUID providerId, Instant startsAt, Instant endsAt) {
        var request = new CreateAvailabilitySlotRequest(startsAt, endsAt);
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
