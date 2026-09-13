package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.reactivationengine.ReactivationCampaign;
import com.zairo.factory.reactivationengine.ReactivationCampaignRepository;
import com.zairo.factory.rebookengine.RebookCampaign;
import com.zairo.factory.rebookengine.RebookCampaignRepository;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.smartfill.SmartFillCampaign;
import com.zairo.factory.smartfill.SmartFillCampaignRepository;
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
 * Against a real Postgres (Testcontainers), same style as {@link
 * BusinessAnalyticsApiTests}. Smart Fill scenarios drive the real
 * cancellation flow (same "favorite the provider, then cancel a booking"
 * technique {@link SmartFillApiTests} already uses) so campaign state is
 * genuine, not guessed; Rebook/Reactivation campaigns -- which have no
 * cheap way to trigger their own real trigger events in a unit-style test
 * -- are constructed directly via their own public constructor and saved
 * through their own repository, the same technique {@link
 * BusinessAnalyticsApiTests#actionCenterSurfacesActiveSmartFillOpportunitiesButNotResolvedCampaigns}
 * already established for SmartFillCampaign.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class CampaignCenterApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private SmartFillCampaignRepository smartFillCampaignRepository;

    @Autowired
    private RebookCampaignRepository rebookCampaignRepository;

    @Autowired
    private ReactivationCampaignRepository reactivationCampaignRepository;

    @Test
    void listReturnsCampaignsFromAllThreeEnginesForThisProviderOnlyAndFiltersByType() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-list-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC List Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC List Service " + runId, new BigDecimal("20.00"));

        Registered follower = TestAuth.registerCustomer(restTemplate, "cc-list-follower-" + runId + "@example.com");
        addFavorite(follower, providerId);
        Registered canceller = TestAuth.registerCustomer(restTemplate, "cc-list-canceller-" + runId + "@example.com");
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = bookWithPrice(canceller, serviceId, slotId, new BigDecimal("20.00"));
        cancelBooking(canceller, cancelledBookingId);

        rebookCampaignRepository.save(new RebookCampaign(UUID.randomUUID(), providerId, serviceId, follower.userId(),
                UUID.randomUUID(), Instant.now().minus(20, ChronoUnit.DAYS), 14, Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(15, ChronoUnit.DAYS), new BigDecimal("25.00"), "USD", Instant.now()));
        reactivationCampaignRepository.save(new ReactivationCampaign(UUID.randomUUID(), providerId, serviceId,
                follower.userId(), UUID.randomUUID(), Instant.now().minus(90, ChronoUnit.DAYS), 90,
                Instant.now().plus(30, ChronoUnit.DAYS), new BigDecimal("30.00"), "USD", Instant.now()));

        // A different provider's own Smart Fill campaign -- must never leak into providerId's list.
        UUID otherProviderId = createProvider(TestAuth.registerOwner(restTemplate, "cc-list-other-" + runId + "@example.com"),
                "CC Other Salon " + runId);
        smartFillCampaignRepository.save(new SmartFillCampaign(UUID.randomUUID(), otherProviderId, UUID.randomUUID(),
                null, UUID.randomUUID(), UUID.randomUUID(), start, start.plus(30, ChronoUnit.MINUTES),
                new BigDecimal("10.00"), "USD", Instant.now()));

        Map<?, ?> unfiltered = getList(owner, providerId, "");
        assertThat(((Number) unfiltered.get("totalItems")).longValue()).isEqualTo(3);
        List<Object> items = asList(unfiltered.get("items"));
        assertThat(items).hasSize(3);
        List<Object> types = items.stream().map(i -> (Object) ((Map<?, ?>) i).get("type")).toList();
        assertThat(types).containsExactlyInAnyOrder("SMART_FILL", "REBOOK", "REACTIVATION");

        Map<?, ?> onlyRebook = getList(owner, providerId, "type=REBOOK");
        assertThat(((Number) onlyRebook.get("totalItems")).longValue()).isEqualTo(1);
        assertThat(asList(onlyRebook.get("items"))).allMatch(i -> ((Map<?, ?>) i).get("type").equals("REBOOK"));

        Map<?, ?> onlyActive = getList(owner, providerId, "status=ACTIVE");
        assertThat(((Number) onlyActive.get("totalItems")).longValue()).isEqualTo(3);
    }

    @Test
    void listPaginatesStably() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-page-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Page Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC Page Service " + runId, new BigDecimal("10.00"));
        Registered customer = TestAuth.registerCustomer(restTemplate, "cc-page-customer-" + runId + "@example.com");

        for (int i = 0; i < 3; i++) {
            reactivationCampaignRepository.save(new ReactivationCampaign(UUID.randomUUID(), providerId, serviceId,
                    customer.userId(), UUID.randomUUID(), Instant.now().minus(90, ChronoUnit.DAYS), 90,
                    Instant.now().plus(30, ChronoUnit.DAYS), new BigDecimal("10.00"), "USD",
                    Instant.now().minus(i, ChronoUnit.MINUTES)));
        }

        Map<?, ?> firstPage = getList(owner, providerId, "pageSize=2&page=0");
        assertThat((List<?>) firstPage.get("items")).hasSize(2);
        assertThat(firstPage.get("totalItems")).isEqualTo(3);
        assertThat(firstPage.get("totalPages")).isEqualTo(2);

        Map<?, ?> secondPage = getList(owner, providerId, "pageSize=2&page=1");
        assertThat((List<?>) secondPage.get("items")).hasSize(1);
    }

    @Test
    void statsAggregateAcrossEngines() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-stats-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Stats Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC Stats Service " + runId, new BigDecimal("40.00"));
        Registered winner = TestAuth.registerCustomer(restTemplate, "cc-stats-winner-" + runId + "@example.com");
        addFavorite(winner, providerId);
        Registered canceller = TestAuth.registerCustomer(restTemplate, "cc-stats-canceller-" + runId + "@example.com");

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = bookWithPrice(canceller, serviceId, slotId, new BigDecimal("40.00"));
        cancelBooking(canceller, cancelledBookingId);
        // The favoriting winner books the freed slot -- a real, recovered Smart Fill campaign.
        bookWithPrice(winner, serviceId, slotId, new BigDecimal("40.00"));

        Map<?, ?> stats = getStats(owner, providerId);
        assertThat(((Number) stats.get("completedCampaigns")).longValue()).isEqualTo(1);
        assertThat(((Number) stats.get("recoveredSlots")).longValue()).isEqualTo(1);
        assertThat(((Number) stats.get("totalRecoveredRevenue")).doubleValue()).isEqualTo(40.00);
        assertThat(((Number) stats.get("conversionRate")).doubleValue()).isEqualTo(1.0);
    }

    @Test
    void smartFillPauseResumeCancelLifecycleIsSafeAndIdempotent() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-lifecycle-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Lifecycle Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC Lifecycle Service " + runId, new BigDecimal("15.00"));
        Registered follower = TestAuth.registerCustomer(restTemplate, "cc-lifecycle-follower-" + runId + "@example.com");
        addFavorite(follower, providerId);
        Registered canceller = TestAuth.registerCustomer(restTemplate, "cc-lifecycle-canceller-" + runId + "@example.com");

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = bookWithPrice(canceller, serviceId, slotId, new BigDecimal("15.00"));
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = smartFillCampaignRepository.findByCancelledBookingId(cancelledBookingId)
                .orElseThrow();
        assertThat(campaign.getStatus().name()).isEqualTo("NOTIFYING");

        Map<?, ?> paused = postAction(owner, providerId, "SMART_FILL", campaign.getId(), "pause", HttpStatus.OK);
        assertThat(paused.get("status")).isEqualTo("PAUSED");
        assertThat(asList(paused.get("availableActions"))).containsExactlyInAnyOrder("RESUME", "CANCEL");

        // Pausing an already-paused campaign is a safe no-op, not an error that duplicates state.
        postAction(owner, providerId, "SMART_FILL", campaign.getId(), "pause", HttpStatus.CONFLICT);

        Map<?, ?> resumed = postAction(owner, providerId, "SMART_FILL", campaign.getId(), "resume", HttpStatus.OK);
        assertThat(resumed.get("status")).isEqualTo("ACTIVE");
        assertThat(resumed.get("rawStatus")).isEqualTo("NOTIFYING");

        Map<?, ?> cancelled = postAction(owner, providerId, "SMART_FILL", campaign.getId(), "cancel", HttpStatus.OK);
        assertThat(cancelled.get("status")).isEqualTo("CANCELLED");
        assertThat((List<?>) cancelled.get("availableActions")).isEmpty();

        // A cancelled campaign can never be incorrectly restarted.
        postAction(owner, providerId, "SMART_FILL", campaign.getId(), "cancel", HttpStatus.CONFLICT);
        postAction(owner, providerId, "SMART_FILL", campaign.getId(), "resume", HttpStatus.CONFLICT);
    }

    @Test
    void retryFindsNewCandidatesForACampaignThatFirstFailedWithNone() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-retry-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Retry Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC Retry Service " + runId, new BigDecimal("18.00"));
        Registered canceller = TestAuth.registerCustomer(restTemplate, "cc-retry-canceller-" + runId + "@example.com");

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = bookWithPrice(canceller, serviceId, slotId, new BigDecimal("18.00"));
        // No one favorites/has booked this brand-new provider yet -- the campaign expires immediately, FAILED.
        cancelBooking(canceller, cancelledBookingId);

        SmartFillCampaign campaign = smartFillCampaignRepository.findByCancelledBookingId(cancelledBookingId)
                .orElseThrow();
        assertThat(campaign.getStatus().name()).isEqualTo("EXPIRED");

        Map<?, ?> detail = getDetail(owner, providerId, "SMART_FILL", campaign.getId());
        assertThat(detail.get("status")).isEqualTo("FAILED");
        assertThat(detail.get("failureReason")).isEqualTo("NO_CANDIDATES_NOTIFIED");
        assertThat(asList(detail.get("availableActions"))).containsExactly("RETRY");

        Map<?, ?> smartActions = getSmartActions(owner, providerId);
        List<Object> smartActionTypes = asList(smartActions.get("items")).stream()
                .map(i -> (Object) ((Map<?, ?>) i).get("type")).toList();
        assertThat(smartActionTypes).contains("FAILED_CAMPAIGN");

        // A candidate appears after the fact -- retry should now find them.
        Registered lateFollower = TestAuth.registerCustomer(restTemplate, "cc-retry-late-" + runId + "@example.com");
        addFavorite(lateFollower, providerId);

        Map<?, ?> retried = postAction(owner, providerId, "SMART_FILL", campaign.getId(), "retry", HttpStatus.OK);
        assertThat(retried.get("status")).isEqualTo("ACTIVE");
        assertThat(((Number) retried.get("candidateCount")).intValue()).isGreaterThanOrEqualTo(1);

        // Already active now -- retrying again is a no-op 409, not a duplicate notification round.
        postAction(owner, providerId, "SMART_FILL", campaign.getId(), "retry", HttpStatus.CONFLICT);
    }

    @Test
    void cancelWorksForRebookAndReactivationButPauseAndRetryDoNot() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-other-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Other Types Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC Other Types Service " + runId, new BigDecimal("22.00"));
        Registered customer = TestAuth.registerCustomer(restTemplate, "cc-other-customer-" + runId + "@example.com");

        RebookCampaign rebook = rebookCampaignRepository.save(new RebookCampaign(UUID.randomUUID(), providerId,
                serviceId, customer.userId(), UUID.randomUUID(), Instant.now().minus(20, ChronoUnit.DAYS), 14,
                Instant.now().plus(1, ChronoUnit.DAYS), Instant.now().plus(15, ChronoUnit.DAYS),
                new BigDecimal("22.00"), "USD", Instant.now()));

        postAction(owner, providerId, "REBOOK", rebook.getId(), "pause", HttpStatus.CONFLICT);
        Map<?, ?> cancelledRebook = postAction(owner, providerId, "REBOOK", rebook.getId(), "cancel", HttpStatus.OK);
        assertThat(cancelledRebook.get("status")).isEqualTo("CANCELLED");
        postAction(owner, providerId, "REBOOK", rebook.getId(), "cancel", HttpStatus.CONFLICT);

        ReactivationCampaign reactivation = reactivationCampaignRepository.save(new ReactivationCampaign(
                UUID.randomUUID(), providerId, serviceId, customer.userId(), UUID.randomUUID(),
                Instant.now().minus(90, ChronoUnit.DAYS), 90, Instant.now().plus(30, ChronoUnit.DAYS),
                new BigDecimal("22.00"), "USD", Instant.now()));

        postAction(owner, providerId, "REACTIVATION", reactivation.getId(), "retry", HttpStatus.CONFLICT);
        Map<?, ?> cancelledReactivation = postAction(owner, providerId, "REACTIVATION", reactivation.getId(), "cancel",
                HttpStatus.OK);
        assertThat(cancelledReactivation.get("status")).isEqualTo("CANCELLED");
    }

    @Test
    void onlyTheOwnerCanReadOrActOnCampaignsAndACampaignUnderTheWrongProviderIs404() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-auth-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "cc-auth-other-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Auth Salon " + runId);
        UUID otherProviderId = createProvider(otherOwner, "CC Auth Other Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC Auth Service " + runId, new BigDecimal("12.00"));

        SmartFillCampaign campaign = smartFillCampaignRepository.save(new SmartFillCampaign(UUID.randomUUID(),
                providerId, serviceId, null, UUID.randomUUID(), UUID.randomUUID(),
                Instant.now().plus(1, ChronoUnit.DAYS), Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES),
                new BigDecimal("12.00"), "USD", Instant.now()));

        ResponseEntity<Map> forbiddenList = restTemplate.exchange("/api/v1/providers/" + providerId + "/campaigns",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbiddenList.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // The campaign really exists, but under a different provider than the one in the path.
        ResponseEntity<Map> wrongProvider = restTemplate.exchange(
                "/api/v1/providers/" + otherProviderId + "/campaigns/SMART_FILL/" + campaign.getId(), HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(wrongProvider.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        Map<?, ?> ok = getDetail(owner, providerId, "SMART_FILL", campaign.getId());
        assertThat(ok.get("id")).isEqualTo(campaign.getId().toString());
    }

    @Test
    void aFreshProviderGetsSafeEmptyResultsRatherThanAnError() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-empty-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Empty Salon " + runId);

        Map<?, ?> list = getList(owner, providerId, "");
        assertThat(list.get("totalItems")).isEqualTo(0);
        assertThat((List<?>) list.get("items")).isEmpty();

        Map<?, ?> stats = getStats(owner, providerId);
        assertThat(stats.get("activeCampaigns")).isEqualTo(0);
        assertThat(((Number) stats.get("totalRecoveredRevenue")).doubleValue()).isEqualTo(0.0);
        assertThat(stats.get("averageCompletionMinutes")).isNull();

        Map<?, ?> smartActions = getSmartActions(owner, providerId);
        assertThat((List<?>) smartActions.get("items")).isEmpty();
    }

    @Test
    void timelineOnlyReflectsRealStoredTimestampsNeverAFabricatedEvent() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "cc-timeline-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "CC Timeline Salon " + runId);
        UUID serviceId = createService(owner, providerId, "CC Timeline Service " + runId, new BigDecimal("16.00"));
        Registered follower = TestAuth.registerCustomer(restTemplate, "cc-timeline-follower-" + runId + "@example.com");
        addFavorite(follower, providerId);
        Registered canceller = TestAuth.registerCustomer(restTemplate, "cc-timeline-canceller-" + runId + "@example.com");

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = bookWithPrice(canceller, serviceId, slotId, new BigDecimal("16.00"));
        cancelBooking(canceller, cancelledBookingId);
        SmartFillCampaign campaign = smartFillCampaignRepository.findByCancelledBookingId(cancelledBookingId)
                .orElseThrow();

        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/campaigns/SMART_FILL/" + campaign.getId() + "/timeline",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<Object> eventTypes = asList(response.getBody().get("events")).stream()
                .map(e -> (Object) ((Map<?, ?>) e).get("type")).toList();
        assertThat(eventTypes).contains("CAMPAIGN_CREATED", "CANDIDATES_SELECTED", "NOTIFICATION_SENT");
        assertThat(eventTypes).doesNotContain("CAMPAIGN_CANCELLED", "SLOT_RECOVERED", "CAMPAIGN_EXPIRED");
    }

    @SuppressWarnings("unchecked")
    private static List<Object> asList(Object value) {
        return (List<Object>) value;
    }

    private Map<?, ?> getList(Registered owner, UUID providerId, String query) {
        String path = "/api/v1/providers/" + providerId + "/campaigns" + (query.isEmpty() ? "" : "?" + query);
        ResponseEntity<Map> response = restTemplate.exchange(path, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private Map<?, ?> getStats(Registered owner, UUID providerId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/campaigns/stats",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private Map<?, ?> getSmartActions(Registered owner, UUID providerId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/smart-actions",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private Map<?, ?> getDetail(Registered owner, UUID providerId, String type, UUID campaignId) {
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/campaigns/" + type + "/" + campaignId, HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private Map<?, ?> postAction(Registered owner, UUID providerId, String type, UUID campaignId, String action,
            HttpStatus expected) {
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/campaigns/" + type + "/" + campaignId + "/" + action,
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(expected);
        return response.getBody();
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

    private UUID bookWithPrice(Registered customer, UUID serviceId, UUID slotId, BigDecimal price) {
        var request = new CreateBookingRequest(customer.userId(), serviceId, slotId, price);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private void cancelBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private void addFavorite(Registered user, UUID providerId) {
        ResponseEntity<Void> response = restTemplate.exchange(
                "/api/v1/users/" + user.userId() + "/favorites/" + providerId, HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(user.accessToken())), Void.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }
}
