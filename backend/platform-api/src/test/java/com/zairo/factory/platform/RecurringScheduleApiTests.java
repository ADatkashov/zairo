package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.RecurringScheduleRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
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
 * Against a real Postgres (Testcontainers): generating a weekly pattern into
 * real slots, holiday skipping, duplicate-generation safety (running the
 * same schedule twice creates nothing new the second time), validation, and
 * ownership.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class RecurringScheduleApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void generatesSlotsForSelectedDaysAndDetectsDuplicateRuns() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "recurring-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Recurring Salon " + runId);
        // Recurring schedule generation is PRO-only — this test is about the
        // generation logic itself, covered separately for the FREE-plan
        // gate by SubscriptionApiTests.
        TestAuth.upgradeToPro(restTemplate, owner);

        LocalDate monday = nextDayOfWeek(DayOfWeek.MONDAY);
        LocalDate sunday = monday.plusDays(6);
        var request = new RecurringScheduleRequest(List.of(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY),
                LocalTime.of(10, 0), LocalTime.of(11, 0), 30, 0, monday, sunday, List.of(), "UTC");

        ResponseEntity<Map> firstRun = generate(providerId, owner, request);
        assertThat(firstRun.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        List<?> created = (List<?>) firstRun.getBody().get("created");
        // Monday + Wednesday in one week, 2 slots each (10:00-10:30, 10:30-11:00).
        assertThat(created).hasSize(4);
        assertThat(firstRun.getBody().get("skippedConflictCount")).isEqualTo(0);

        ResponseEntity<Map> secondRun = generate(providerId, owner, request);
        assertThat(secondRun.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat((List<?>) secondRun.getBody().get("created")).isEmpty();
        assertThat(secondRun.getBody().get("skippedConflictCount")).isEqualTo(4);
    }

    @Test
    void skipsHolidaysEvenOnASelectedDayOfWeek() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "recurring-holiday-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Recurring Holiday Salon " + runId);
        TestAuth.upgradeToPro(restTemplate, owner);

        LocalDate monday = nextDayOfWeek(DayOfWeek.MONDAY);
        var request = new RecurringScheduleRequest(List.of(DayOfWeek.MONDAY), LocalTime.of(10, 0),
                LocalTime.of(11, 0), 30, 0, monday, monday, List.of(monday), "UTC");

        ResponseEntity<Map> response = generate(providerId, owner, request);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat((List<?>) response.getBody().get("created")).isEmpty();
        assertThat(response.getBody().get("skippedConflictCount")).isEqualTo(0);
    }

    @Test
    void rejectsAStartTimeThatIsNotBeforeEndTime() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "recurring-invalid-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Recurring Invalid Salon " + runId);
        TestAuth.upgradeToPro(restTemplate, owner);

        LocalDate monday = nextDayOfWeek(DayOfWeek.MONDAY);
        var request = new RecurringScheduleRequest(List.of(DayOfWeek.MONDAY), LocalTime.of(11, 0),
                LocalTime.of(10, 0), 30, 0, monday, monday, List.of(), "UTC");

        ResponseEntity<Map> response = generate(providerId, owner, request);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void onlyTheOwnerCanGenerateARecurringSchedule() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "recurring-owner2-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "recurring-other-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Recurring Owned Salon " + runId);

        LocalDate monday = nextDayOfWeek(DayOfWeek.MONDAY);
        var request = new RecurringScheduleRequest(List.of(DayOfWeek.MONDAY), LocalTime.of(10, 0),
                LocalTime.of(11, 0), 30, 0, monday, monday, List.of(), "UTC");

        ResponseEntity<Map> response = generate(providerId, otherOwner, request);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    private ResponseEntity<Map> generate(UUID providerId, Registered owner, RecurringScheduleRequest request) {
        return restTemplate.exchange("/api/v1/providers/" + providerId + "/availability-slots/recurring",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
    }

    private static LocalDate nextDayOfWeek(DayOfWeek dayOfWeek) {
        LocalDate date = LocalDate.now().plusDays(1);
        while (date.getDayOfWeek() != dayOfWeek) {
            date = date.plusDays(1);
        }
        return date;
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
