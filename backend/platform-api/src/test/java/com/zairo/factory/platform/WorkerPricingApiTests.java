package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.staff.StaffBookingDtos.CreateStaffBookingRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.IntStream;
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

/** Different prices per master: owner-controlled, fixed at booking time, and never imposed by "any master". */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class WorkerPricingApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    private static Instant tomorrowAt(int hour) {
        return LocalDate.now(ZoneOffset.UTC).plusDays(1).atTime(hour, 0).toInstant(ZoneOffset.UTC);
    }

    /** A business with two scheduled people (09:00-12:00 UTC, every day) who both do the service. */
    private record Salon(Registered owner, UUID providerId, UUID serviceId, UUID first, UUID second) {
    }

    private Salon salon(String tag) {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, tag + "-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, tag + " Salon " + runId);
        UUID serviceId = createService(owner, providerId);
        UUID first = createStaff(owner, providerId, "Alpha");
        UUID second = createStaff(owner, providerId, "Beta");
        for (UUID staff : List.of(first, second)) {
            post("/api/v1/staff/" + staff + "/services/" + serviceId, owner, null);
            restTemplate.exchange("/api/v1/providers/" + providerId + "/workers/" + staff + "/schedule",
                    HttpMethod.PUT, new HttpEntity<>(Map.of("zoneId", "UTC", "slotMinutes", 60, "breakMinutes", 0,
                            "hours", IntStream.rangeClosed(1, 7).mapToObj(d -> Map.of("dayOfWeek", d,
                                    "startTime", "09:00:00", "endTime", "12:00:00")).toList()),
                            TestAuth.authHeaders(owner.accessToken())), Map.class);
        }
        return new Salon(owner, providerId, serviceId, first, second);
    }

    private UUID bookNamed(Salon salon, Registered customer, UUID staff, int hour) {
        Map<?, ?> slot = slotsOf(salon, staff).stream()
                .filter(s -> Instant.parse(s.get("startsAt").toString()).equals(tomorrowAt(hour))).findFirst()
                .orElseThrow();
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/staff/bookings", HttpMethod.POST,
                new HttpEntity<>(new CreateStaffBookingRequest(customer.userId(), staff, salon.serviceId(),
                        UUID.fromString(slot.get("id").toString()), new BigDecimal("25.00")),
                        TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("bookingId").toString());
    }

    private Map<?, ?> bookAny(Salon salon, Registered customer, int hour) {
        ResponseEntity<Map> response = post("/api/v1/providers/" + salon.providerId() + "/bookings/any", customer,
                Map.of("userId", customer.userId().toString(), "serviceId", salon.serviceId().toString(),
                        "startsAt", tomorrowAt(hour).toString()));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return response.getBody();
    }

    private ResponseEntity<Map> notIn(Salon salon, UUID staff) {
        Instant from = tomorrowAt(0);
        return post("/api/v1/providers/" + salon.providerId() + "/workers/" + staff + "/time-off", salon.owner(),
                Map.of("startsAt", from.toString(), "endsAt", from.plusSeconds(86400).toString(), "reason", "Sick"));
    }

    private void setPricing(Salon salon, boolean on) {
        ResponseEntity<Map> r = restTemplate.exchange("/api/v1/providers/" + salon.providerId() + "/workforce-settings",
                HttpMethod.PUT, new HttpEntity<>(Map.of("allowWorkerChoice", true, "workerPricingEnabled", on),
                        TestAuth.authHeaders(salon.owner().accessToken())), Map.class);
        assertThat(r.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private ResponseEntity<Object> setPrice(Salon salon, Registered as, UUID worker, Object price) {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("serviceId", salon.serviceId().toString());
        body.put("price", price);
        return restTemplate.exchange("/api/v1/providers/" + salon.providerId() + "/workers/" + worker + "/prices",
                HttpMethod.PUT, new HttpEntity<>(body, TestAuth.authHeaders(as.accessToken())), Object.class);
    }

    private double priceOf(Registered as, UUID bookingId) {
        return ((Number) restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Map.class).getBody()
                .get("totalPrice")).doubleValue();
    }

    @Test
    void aMastersOwnPriceAppliesOnlyWhenSwitchedOnAndIsFixedAtBooking() {
        Salon salon = salon("prc1");
        Registered c1 = TestAuth.registerCustomer(restTemplate, "prc1-a-" + UUID.randomUUID() + "@example.com");
        Registered c2 = TestAuth.registerCustomer(restTemplate, "prc1-b-" + UUID.randomUUID() + "@example.com");
        Registered c3 = TestAuth.registerCustomer(restTemplate, "prc1-c-" + UUID.randomUUID() + "@example.com");
        Registered stranger = TestAuth.registerOwner(restTemplate, "prc1-s-" + UUID.randomUUID() + "@example.com");

        // Only the owner can set it.
        assertThat(setPrice(salon, stranger, salon.first(), 40).getStatusCode().is4xxClientError()).isTrue();
        assertThat(setPrice(salon, salon.owner(), salon.first(), 40).getStatusCode()).isEqualTo(HttpStatus.OK);

        // Switched off (default): everyone pays the service's price, and customers see no differing prices.
        assertThat(priceOf(c1, bookNamed(salon, c1, salon.first(), 9))).isEqualTo(25.0);
        assertThat(restTemplate.getForObject("/api/v1/providers/" + salon.providerId() + "/services/"
                + salon.serviceId() + "/worker-prices", List.class)).isEmpty();

        // Switched on: the chosen master's price applies...
        setPricing(salon, true);
        UUID premium = bookNamed(salon, c2, salon.first(), 10);
        assertThat(priceOf(c2, premium)).isEqualTo(40.0);
        assertThat(restTemplate.getForObject("/api/v1/providers/" + salon.providerId() + "/services/"
                + salon.serviceId() + "/worker-prices", List.class)).hasSize(1);
        // ...a colleague without an override charges the base price...
        assertThat(priceOf(c3, bookNamed(salon, c3, salon.second(), 10))).isEqualTo(25.0);
        // ...and later edits never change a booking already made.
        setPrice(salon, salon.owner(), salon.first(), 99);
        assertThat(priceOf(c2, premium)).isEqualTo(40.0);
    }

    @Test
    void anyMasterNeverAssignsSomeoneWhoChargesADifferentPrice() {
        Salon salon = salon("prc2");
        setPricing(salon, true);
        setPrice(salon, salon.owner(), salon.first(), 40);

        for (int hour : new int[] {9, 10, 11}) {
            Registered customer = TestAuth.registerCustomer(restTemplate,
                    "prc2-" + hour + "-" + UUID.randomUUID() + "@example.com");
            Map<?, ?> booking = bookAny(salon, customer, hour);
            // Beta is the only one at the base price, so "any" always lands on Beta, at the base price.
            assertThat(booking.get("workerId")).isEqualTo(salon.second().toString());
            assertThat(priceOf(customer, UUID.fromString(booking.get("bookingId").toString()))).isEqualTo(25.0);
        }
    }

    private Map<?, ?> bookingOf(Registered as, UUID bookingId) {
        return restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Map.class).getBody();
    }

    private void pay(Registered customer, UUID bookingId) {
        restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
    }

    private ResponseEntity<Map> reassign(Salon salon, UUID bookingId, UUID toWorker) {
        return post("/api/v1/providers/" + salon.providerId() + "/appointments/" + bookingId + "/reassign",
                salon.owner(), Map.of("workerId", toWorker.toString()));
    }

    @Test
    void aCheaperReplacementLowersThePriceAndReturnsWhatWasPaidAboveItButAPricierOneNeverCostsMore() {
        Salon salon = salon("prc3");
        setPricing(salon, true);
        setPrice(salon, salon.owner(), salon.first(), 40);
        Registered premiumCustomer = TestAuth.registerCustomer(restTemplate, "prc3-a-" + UUID.randomUUID() + "@example.com");
        Registered baseCustomer = TestAuth.registerCustomer(restTemplate, "prc3-b-" + UUID.randomUUID() + "@example.com");

        // Paid 40 for the premium master; the colleague charges 25 -> the booking becomes 25 and 15 goes back.
        UUID premium = bookNamed(salon, premiumCustomer, salon.first(), 9);
        assertThat(priceOf(premiumCustomer, premium)).isEqualTo(40.0);
        pay(premiumCustomer, premium);
        assertThat(((Number) bookingOf(premiumCustomer, premium).get("paidAmount")).doubleValue()).isEqualTo(40.0);
        assertThat(reassign(salon, premium, salon.second()).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        Map<?, ?> after = bookingOf(premiumCustomer, premium);
        assertThat(((Number) after.get("totalPrice")).doubleValue()).isEqualTo(25.0);
        assertThat(((Number) after.get("paidAmount")).doubleValue()).isEqualTo(25.0);
        assertThat(((Number) after.get("remainingAmount")).doubleValue()).isEqualTo(0.0);

        // Booked at the base price with the colleague; the owner hands it to the premium master -> still 25.
        UUID basic = bookNamed(salon, baseCustomer, salon.second(), 10);
        pay(baseCustomer, basic);
        assertThat(reassign(salon, basic, salon.first()).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(priceOf(baseCustomer, basic)).isEqualTo(25.0);
        assertThat(((Number) bookingOf(baseCustomer, basic).get("paidAmount")).doubleValue()).isEqualTo(25.0);
    }

    // --- helpers ---

    /** The worker a booking is with: whose slot (or link) it is attributed to, by the slots they own. */
    private UUID ownedBy(Salon salon, UUID bookingId) {
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(salon.owner().accessToken())), Map.class).getBody();
        String slotId = booking.get("availabilitySlotId").toString();
        for (UUID staff : List.of(salon.first(), salon.second())) {
            if (slotsOf(salon, staff).stream().anyMatch(s -> slotId.equals(s.get("id").toString()))) {
                return staff;
            }
        }
        throw new AssertionError("No staff owns slot " + slotId);
    }

    private String bookingStatus(Registered as, UUID bookingId) {
        return restTemplate.exchange("/api/v1/bookings/" + bookingId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(as.accessToken())), Map.class).getBody()
                .get("status").toString();
    }

    private List<Map> slotsOf(Salon salon, UUID staff) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(
                "/api/v1/providers/" + salon.providerId() + "/availability-slots?employeeId=" + staff, Map[].class);
        return List.of(response.getBody());
    }

    private List<Map> needsAttention(Salon salon) {
        ResponseEntity<Map[]> response = restTemplate.exchange(
                "/api/v1/providers/" + salon.providerId() + "/appointments/needs-attention", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(salon.owner().accessToken())), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private List<Map> changeRequests(Registered customer) {
        ResponseEntity<Map[]> response = restTemplate.exchange("/api/v1/me/change-requests", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private ResponseEntity<Map> respond(Registered customer, UUID bookingId, Map<String, String> body) {
        return post("/api/v1/me/change-requests/" + bookingId + "/respond", customer, body);
    }

    private ResponseEntity<Map> post(String path, Registered as, Object body) {
        return restTemplate.exchange(path, HttpMethod.POST, new HttpEntity<>(body,
                TestAuth.authHeaders(as.accessToken())), Map.class);
    }

    private UUID createProvider(Registered owner, String name) {
        ResponseEntity<Map> response = post("/api/v1/providers", owner,
                new CreateProviderRequest(owner.userId(), name, "sport_fitness"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString(response.getBody().get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        return providerId;
    }

    private UUID createService(Registered owner, UUID providerId) {
        ResponseEntity<Map> response = post("/api/v1/providers/" + providerId + "/services", owner,
                new CreateServiceRequest("Cut", 60, new BigDecimal("25.00"), "USD"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createStaff(Registered owner, UUID providerId, String name) {
        ResponseEntity<Map> response = post("/api/v1/providers/" + providerId + "/staff", owner,
                Map.of("displayName", name, "bio", "Bio"));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}

