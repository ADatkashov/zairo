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

/**
 * "The master can't make it": customers who said "any master" go to a free colleague without being asked; a named
 * person's customer is asked (colleague / another time / cancel), or the owner decides.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class WorkerChangeApiTests {

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

    @Test
    void anyMasterCustomersGoToAFreeColleagueButANamedPersonWaitsForTheOwner() {
        Salon salon = salon("chg1");
        Registered anyCustomer = TestAuth.registerCustomer(restTemplate, "chg1-any-" + UUID.randomUUID() + "@example.com");
        Registered namedCustomer = TestAuth.registerCustomer(restTemplate, "chg1-named-" + UUID.randomUUID() + "@example.com");

        // "Any" lands on someone; the named customer then books that same person later, and that person is off.
        Map<?, ?> any = bookAny(salon, anyCustomer, 10);
        UUID anyBooking = UUID.fromString(any.get("bookingId").toString());
        UUID absent = UUID.fromString(any.get("workerId").toString());
        UUID colleague = absent.equals(salon.first()) ? salon.second() : salon.first();
        UUID named = bookNamed(salon, namedCustomer, absent, 11);

        ResponseEntity<Map> off = notIn(salon, absent);
        assertThat(off.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // The "any master" appointment moved to the colleague, silently.
        assertThat(ownedBy(salon, anyBooking)).isEqualTo(colleague);
        // The named one stays and waits for the owner, who sees who could take it.
        List<Map> needs = needsAttention(salon);
        assertThat(needs).extracting(n -> n.get("bookingId")).containsExactly(named.toString());
        Map<?, ?> item = needs.get(0);
        assertThat(item.get("reason")).isEqualTo("WORKER_UNAVAILABLE");
        assertThat(item.get("preference")).isEqualTo("SPECIFIC");
        assertThat((List<Map>) item.get("replacements")).extracting(r -> r.get("workerId"))
                .contains(colleague.toString());
        assertThat(((Number) off.getBody().get("affectedAppointments")).intValue()).isEqualTo(1);
    }

    @Test
    void theOwnerCanGiveANamedAppointmentToAColleagueAndOnlyIfTheyAreFree() {
        Salon salon = salon("chg2");
        Registered customer = TestAuth.registerCustomer(restTemplate, "chg2-c-" + UUID.randomUUID() + "@example.com");
        Registered other = TestAuth.registerCustomer(restTemplate, "chg2-o-" + UUID.randomUUID() + "@example.com");
        Registered stranger = TestAuth.registerOwner(restTemplate, "chg2-s-" + UUID.randomUUID() + "@example.com");

        UUID busy = bookNamed(salon, customer, salon.first(), 10);
        UUID free = bookNamed(salon, other, salon.first(), 11);
        // Beta is busy at 10:00, so can't take that one.
        bookNamed(salon, TestAuth.registerCustomer(restTemplate, "chg2-b-" + UUID.randomUUID() + "@example.com"),
                salon.second(), 10);
        notIn(salon, salon.first());
        String base = "/api/v1/providers/" + salon.providerId() + "/appointments/";
        assertThat(post(base + busy + "/reassign", salon.owner(), Map.of("workerId", salon.second().toString()))
                .getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        // A stranger can't do any of this.
        assertThat(post(base + free + "/reassign", stranger, Map.of("workerId", salon.second().toString()))
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        // At 11:00 Beta is free: the owner hands it over.
        assertThat(post(base + free + "/reassign", salon.owner(), Map.of("workerId", salon.second().toString()))
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(ownedBy(salon, free)).isEqualTo(salon.second());
    }

    @Test
    void theCustomerOfANamedPersonChoosesAColleagueAnotherTimeOrToCancel() {
        Salon salon = salon("chg3");
        Registered replaceC = TestAuth.registerCustomer(restTemplate, "chg3-r-" + UUID.randomUUID() + "@example.com");
        Registered moveC = TestAuth.registerCustomer(restTemplate, "chg3-m-" + UUID.randomUUID() + "@example.com");
        Registered cancelC = TestAuth.registerCustomer(restTemplate, "chg3-x-" + UUID.randomUUID() + "@example.com");
        Registered otherC = TestAuth.registerCustomer(restTemplate, "chg3-o-" + UUID.randomUUID() + "@example.com");

        UUID toReplace = bookNamed(salon, replaceC, salon.first(), 9);
        UUID toMove = bookNamed(salon, moveC, salon.first(), 10);
        UUID toCancel = bookNamed(salon, cancelC, salon.first(), 11);
        ResponseEntity<Map> off = notIn(salon, salon.first());
        assertThat(((Number) off.getBody().get("affectedAppointments")).intValue()).isEqualTo(3);

        // Nothing for the customer to answer until the owner asks.
        assertThat(changeRequests(replaceC)).isEmpty();
        for (UUID booking : List.of(toReplace, toMove, toCancel)) {
            assertThat(post("/api/v1/providers/" + salon.providerId() + "/appointments/" + booking + "/ask-customer",
                    salon.owner(), null).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        }
        // Asking twice changes nothing.
        assertThat(post("/api/v1/providers/" + salon.providerId() + "/appointments/" + toReplace + "/ask-customer",
                salon.owner(), null).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(needsAttention(salon)).allSatisfy(n -> assertThat(n.get("customerAskedAt")).isNotNull());

        Map<?, ?> request = changeRequests(replaceC).get(0);
        assertThat(request.get("bookingId")).isEqualTo(toReplace.toString());
        assertThat((List<Map>) request.get("replacements")).extracting(r -> r.get("workerId"))
                .containsExactly(salon.second().toString());

        // Someone else's request isn't theirs to answer.
        assertThat(respond(otherC, toReplace, Map.of("choice", "CANCEL")).getStatusCode())
                .isEqualTo(HttpStatus.FORBIDDEN);

        // REPLACE: the colleague takes it at the same time.
        assertThat(respond(replaceC, toReplace, Map.of("choice", "REPLACE", "workerId", salon.second().toString()))
                .getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(ownedBy(salon, toReplace)).isEqualTo(salon.second());
        assertThat(changeRequests(replaceC)).isEmpty();

        // CANCEL: refunded cancellation.
        assertThat(respond(cancelC, toCancel, Map.of("choice", "CANCEL")).getStatusCode())
                .isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(bookingStatus(cancelC, toCancel)).isEqualTo("CANCELLED");

        // MOVE is only possible when the same person has other times: Alpha is off all of tomorrow only, so the
        // day after tomorrow is offered.
        Map<?, ?> moveRequest = changeRequests(moveC).get(0);
        List<Map> times = (List<Map>) moveRequest.get("otherTimes");
        assertThat(times).isNotEmpty();
        UUID newSlot = UUID.fromString(times.get(0).get("slotId").toString());
        assertThat(respond(moveC, toMove, Map.of("choice", "MOVE", "slotId", newSlot.toString())).getStatusCode())
                .isEqualTo(HttpStatus.NO_CONTENT);
        Map<?, ?> moved = restTemplate.exchange("/api/v1/bookings/" + toMove, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(moveC.accessToken())), Map.class).getBody();
        assertThat(moved.get("availabilitySlotId")).isEqualTo(newSlot.toString());
        assertThat(needsAttention(salon)).isEmpty();
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
        return UUID.fromString(response.getBody().get("id").toString());
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
