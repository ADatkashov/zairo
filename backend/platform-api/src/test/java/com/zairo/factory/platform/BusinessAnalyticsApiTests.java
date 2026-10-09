package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.smartfill.SmartFillCampaign;
import com.zairo.factory.smartfill.SmartFillCampaignRepository;
import com.zairo.factory.smartfill.SmartFillCampaignStatus;
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
import org.springframework.web.util.UriComponentsBuilder;

/**
 * Against a real Postgres (Testcontainers) — the Business Intelligence
 * Dashboard's analytics endpoints, composed live from Booking/Payment/
 * AvailabilitySlot (own module), plus Smart Fill's and Revenue Engine's own
 * analytics and Customer Intelligence's own per-business profiles (see
 * {@code BusinessAnalyticsService}'s doc comment for why none of those
 * three are recomputed here).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class BusinessAnalyticsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private SmartFillCampaignRepository smartFillCampaignRepository;

    @Test
    void overviewComputesRealRevenueAndBookingMixForTheGivenPeriodExcludingCancelledRevenue() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-overview-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Overview Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Facial " + runId, new BigDecimal("40.00"));

        Instant windowStart = Instant.now().minus(1, ChronoUnit.DAYS);
        Instant windowEnd = Instant.now().plus(2, ChronoUnit.DAYS);

        Registered paidCustomer = TestAuth.registerCustomer(restTemplate, "ba-overview-paid-" + runId + "@example.com");
        Instant completedStart = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID completedSlot = createSlot(owner, providerId, completedStart, completedStart.plus(30, ChronoUnit.MINUTES));
        UUID completedBookingId = bookWithPrice(paidCustomer, serviceId, completedSlot, new BigDecimal("40.00"));
        payBooking(paidCustomer, completedBookingId);
        completeBooking(owner, completedBookingId);

        Registered cancellingCustomer = TestAuth.registerCustomer(restTemplate,
                "ba-overview-cancel-" + runId + "@example.com");
        Instant cancelledStart = Instant.now().plus(90, ChronoUnit.MINUTES);
        UUID cancelledSlot = createSlot(owner, providerId, cancelledStart, cancelledStart.plus(30, ChronoUnit.MINUTES));
        UUID cancelledBookingId = bookWithPrice(cancellingCustomer, serviceId, cancelledSlot, new BigDecimal("40.00"));
        cancelBooking(cancellingCustomer, cancelledBookingId);

        Map<?, ?> overview = getAnalytics(owner, providerId, "overview", windowStart, windowEnd);
        assertThat(overview.get("totalBookings")).isEqualTo(2);
        assertThat(overview.get("completedBookings")).isEqualTo(1);
        assertThat(overview.get("cancelledBookings")).isEqualTo(1);
        assertThat(overview.get("noShowBookings")).isEqualTo(0);
        assertThat(((Number) overview.get("cancellationRate")).doubleValue()).isEqualTo(0.5);
        assertThat(((Number) overview.get("noShowRate")).doubleValue()).isEqualTo(0.0);
        // Only the completed, paid booking counts as revenue -- the cancelled one must never appear.
        assertThat(((Number) overview.get("totalRevenue")).doubleValue()).isEqualTo(40.00);
        assertThat(((Number) overview.get("averageBookingValue")).doubleValue()).isEqualTo(40.00);
        assertThat(overview.get("currency")).isEqualTo("USD");
    }

    @Test
    void revenueBreaksDownByDayAndByServiceFromSucceededPaymentsOnly() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-revenue-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Revenue Salon " + runId);
        UUID haircutId = createService(owner, providerId, "Haircut " + runId, new BigDecimal("25.00"));
        UUID manicureId = createService(owner, providerId, "Manicure " + runId, new BigDecimal("35.00"));

        Instant windowStart = Instant.now().minus(1, ChronoUnit.DAYS);
        Instant windowEnd = Instant.now().plus(3, ChronoUnit.DAYS);

        Registered customerA = TestAuth.registerCustomer(restTemplate, "ba-revenue-a-" + runId + "@example.com");
        Instant dayOneStart = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slotA = createSlot(owner, providerId, dayOneStart, dayOneStart.plus(30, ChronoUnit.MINUTES));
        UUID bookingA = bookWithPrice(customerA, haircutId, slotA, new BigDecimal("25.00"));
        payBooking(customerA, bookingA);
        completeBooking(owner, bookingA);

        Registered customerB = TestAuth.registerCustomer(restTemplate, "ba-revenue-b-" + runId + "@example.com");
        Instant dayTwoStart = Instant.now().plus(2, ChronoUnit.DAYS);
        UUID slotB = createSlot(owner, providerId, dayTwoStart, dayTwoStart.plus(30, ChronoUnit.MINUTES));
        UUID bookingB = bookWithPrice(customerB, manicureId, slotB, new BigDecimal("35.00"));
        payBooking(customerB, bookingB);
        completeBooking(owner, bookingB);

        // A cancelled, unpaid booking on the same window -- must never contribute to any breakdown.
        Registered customerC = TestAuth.registerCustomer(restTemplate, "ba-revenue-c-" + runId + "@example.com");
        Instant cancelledStart = Instant.now().plus(1, ChronoUnit.DAYS).plus(2, ChronoUnit.HOURS);
        UUID slotC = createSlot(owner, providerId, cancelledStart, cancelledStart.plus(30, ChronoUnit.MINUTES));
        UUID bookingC = bookWithPrice(customerC, haircutId, slotC, new BigDecimal("25.00"));
        cancelBooking(customerC, bookingC);

        Map<?, ?> revenue = getAnalytics(owner, providerId, "revenue", windowStart, windowEnd);
        assertThat(((Number) revenue.get("totalRevenue")).doubleValue()).isEqualTo(60.00);
        assertThat(((Number) revenue.get("averageBookingValue")).doubleValue()).isEqualTo(30.00);

        List<?> byDay = (List<?>) revenue.get("revenueByDay");
        assertThat(byDay).hasSize(2);
        double dayTotal = byDay.stream().mapToDouble(d -> ((Number) ((Map<?, ?>) d).get("amount")).doubleValue()).sum();
        assertThat(dayTotal).isEqualTo(60.00);

        List<?> byService = (List<?>) revenue.get("revenueByService");
        assertThat(byService).hasSize(2);
        Map<?, ?> haircutRow = byService.stream().map(r -> (Map<?, ?>) r)
                .filter(r -> r.get("title").equals("Haircut " + runId)).findFirst().orElseThrow();
        assertThat(((Number) haircutRow.get("amount")).doubleValue()).isEqualTo(25.00);
        assertThat(haircutRow.get("bookingCount")).isEqualTo(1);
    }

    @Test
    void bookingsAnalyticsExcludesBookingsOutsideTheRangeAndComputesRepeatBookingRate() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-bookings-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Bookings Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Massage " + runId, new BigDecimal("50.00"));

        Registered repeatCustomer = TestAuth.registerCustomer(restTemplate, "ba-bookings-repeat-" + runId + "@example.com");
        Instant inRangeFirst = Instant.now().plus(1, ChronoUnit.DAYS);
        UUID slot1 = createSlot(owner, providerId, inRangeFirst, inRangeFirst.plus(30, ChronoUnit.MINUTES));
        UUID booking1 = bookWithPrice(repeatCustomer, serviceId, slot1, new BigDecimal("50.00"));
        payBooking(repeatCustomer, booking1);
        completeBooking(owner, booking1);

        Instant inRangeSecond = Instant.now().plus(2, ChronoUnit.DAYS);
        UUID slot2 = createSlot(owner, providerId, inRangeSecond, inRangeSecond.plus(30, ChronoUnit.MINUTES));
        UUID booking2 = bookWithPrice(repeatCustomer, serviceId, slot2, new BigDecimal("50.00"));
        payBooking(repeatCustomer, booking2);
        completeBooking(owner, booking2);

        // Outside the queried window entirely -- must not be counted at all.
        Registered outOfRangeCustomer = TestAuth.registerCustomer(restTemplate,
                "ba-bookings-outside-" + runId + "@example.com");
        Instant outOfRangeStart = Instant.now().minus(20, ChronoUnit.DAYS);
        UUID outOfRangeSlot = createSlot(owner, providerId, outOfRangeStart, outOfRangeStart.plus(30, ChronoUnit.MINUTES));
        UUID outOfRangeBooking = bookWithPrice(outOfRangeCustomer, serviceId, outOfRangeSlot, new BigDecimal("50.00"));
        payBooking(outOfRangeCustomer, outOfRangeBooking);
        completeBooking(owner, outOfRangeBooking);

        Instant windowStart = Instant.now();
        Instant windowEnd = Instant.now().plus(3, ChronoUnit.DAYS);
        Map<?, ?> bookings = getAnalytics(owner, providerId, "bookings", windowStart, windowEnd);
        assertThat(bookings.get("totalBookings")).isEqualTo(2);
        assertThat(bookings.get("completedBookings")).isEqualTo(2);
        assertThat(((Number) bookings.get("repeatBookingRate")).doubleValue()).isEqualTo(1.0);
        List<?> trend = (List<?>) bookings.get("trend");
        assertThat(trend).hasSize(2);
    }

    @Test
    void rejectsAFromThatIsNotBeforeTo() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-badrange-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Bad Range Salon " + runId);

        Instant now = Instant.now();
        ResponseEntity<Map> response = exchangeAnalytics(owner, providerId, "overview", now, now.minus(1, ChronoUnit.DAYS));
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void aFreshProviderGetsSafeEmptyAnalyticsRatherThanInventedNumbers() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-empty-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Empty Salon " + runId);

        Map<?, ?> overview = getAnalytics(owner, providerId, "overview", null, null);
        assertThat(overview.get("totalBookings")).isEqualTo(0);
        assertThat(((Number) overview.get("cancellationRate")).doubleValue()).isEqualTo(0.0);
        assertThat(overview.get("currency")).isNull();
        // No availability slots at all in range -- utilization is unavailable, never a guessed number.
        assertThat(overview.get("utilization")).isNull();
        assertThat(((Number) overview.get("revenueRecovered")).doubleValue()).isEqualTo(0.0);

        ResponseEntity<Map> actionsResponse = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/analytics/actions", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(actionsResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat((List<?>) actionsResponse.getBody().get("actions")).isEmpty();
    }

    @Test
    void onlyTheOwnerCanReadBusinessAnalytics() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-auth-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "ba-auth-other-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Auth Salon " + runId);

        ResponseEntity<Map> forbidden = exchangeAnalytics(otherOwner, providerId, "overview", null, null);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Map> ok = exchangeAnalytics(owner, providerId, "overview", null, null);
        assertThat(ok.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    @Test
    void customerAnalyticsReportsRetentionMixFromCustomerIntelligenceProfiles() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-customers-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Customers Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Overdue Service " + runId, new BigDecimal("35.00"));

        // Same technique as CustomerIntelligenceApiTests: establish a 14-day cadence (visits 44 and
        // 30 days ago), landing 30 days since the last visit -- past atRiskFactor (2.0 x 14 = 28)
        // but within inactiveFactor (3.0 x 14 = 42), so DUE_FOR_REBOOKING or AT_RISK.
        Registered overdueCustomer = TestAuth.registerCustomer(restTemplate,
                "ba-customers-overdue-" + runId + "@example.com");
        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        completeVisit(owner, overdueCustomer, providerId, serviceId, today.minus(44, ChronoUnit.DAYS));
        completeVisit(owner, overdueCustomer, providerId, serviceId, today.minus(30, ChronoUnit.DAYS));

        // A brand-new customer whose first (and only) visit is today. "New customer" counts by when the
        // first booking was made (CustomerProviderProfile.firstVisitAt = first booking's createdAt), and
        // every booking here is made now -- backdating only moves the slot -- so both customers are new
        // to a range covering today.
        Registered newCustomer = TestAuth.registerCustomer(restTemplate, "ba-customers-new-" + runId + "@example.com");
        completeVisit(owner, newCustomer, providerId, serviceId, today);

        Map<?, ?> customers = getAnalytics(owner, providerId, "customers", today.minus(1, ChronoUnit.DAYS),
                today.plus(1, ChronoUnit.DAYS));
        assertThat(customers.get("totalCustomers")).isEqualTo(2);
        assertThat(customers.get("newCustomers")).isEqualTo(2);
        long dueForRebooking = ((Number) customers.get("dueForRebooking")).longValue();
        long atRisk = ((Number) customers.get("atRiskCustomers")).longValue();
        assertThat(dueForRebooking + atRisk).isGreaterThanOrEqualTo(1);
    }

    @Test
    void actionCenterSurfacesActiveSmartFillOpportunitiesButNotResolvedCampaigns() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-actions-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Actions Salon " + runId);
        Instant now = Instant.now();

        SmartFillCampaign active = new SmartFillCampaign(UUID.randomUUID(), providerId, UUID.randomUUID(), null,
                UUID.randomUUID(), UUID.randomUUID(), now.plus(1, ChronoUnit.DAYS),
                now.plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES), new BigDecimal("20.00"), "USD", now);
        smartFillCampaignRepository.save(active);

        // A real cancellation with no eligible candidates around -- Smart Fill expires it
        // immediately (see SmartFillApiTests), so it must not count as an "active" opportunity.
        UUID serviceId = createService(owner, providerId, "Actions Service " + runId, new BigDecimal("20.00"));
        Instant resolvedStart = now.plus(2, ChronoUnit.DAYS);
        UUID resolvedSlot = createSlot(owner, providerId, resolvedStart, resolvedStart.plus(30, ChronoUnit.MINUTES));
        Registered canceller = TestAuth.registerCustomer(restTemplate, "ba-actions-canceller-" + runId + "@example.com");
        UUID resolvedBookingId = bookWithPrice(canceller, serviceId, resolvedSlot, new BigDecimal("20.00"));
        cancelBooking(canceller, resolvedBookingId);
        assertThat(smartFillCampaignRepository.findByCancelledBookingId(resolvedBookingId).orElseThrow().getStatus())
                .isEqualTo(SmartFillCampaignStatus.EXPIRED);

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/analytics/actions",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<?> actions = (List<?>) response.getBody().get("actions");
        Map<?, ?> smartFillAction = actions.stream().map(a -> (Map<?, ?>) a)
                .filter(a -> a.get("type").equals("SMART_FILL_OPPORTUNITY")).findFirst().orElseThrow();
        // Exactly the still-active campaign, not the already-expired one.
        assertThat(smartFillAction.get("count")).isEqualTo(1);
    }

    @Test
    void smartFillAnalyticsIsScopedToCampaignsCreatedWithinTheRequestedPeriod() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-sfrange-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA SF Range Salon " + runId);
        Instant now = Instant.now();

        SmartFillCampaign recent = new SmartFillCampaign(UUID.randomUUID(), providerId, UUID.randomUUID(), null,
                UUID.randomUUID(), UUID.randomUUID(), now.plus(1, ChronoUnit.DAYS),
                now.plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES), new BigDecimal("15.00"), "USD", now);
        smartFillCampaignRepository.save(recent);

        SmartFillCampaign old = new SmartFillCampaign(UUID.randomUUID(), providerId, UUID.randomUUID(), null,
                UUID.randomUUID(), UUID.randomUUID(), now.minus(60, ChronoUnit.DAYS),
                now.minus(60, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES), new BigDecimal("15.00"), "USD",
                now.minus(60, ChronoUnit.DAYS));
        smartFillCampaignRepository.save(old);

        Map<?, ?> inRange = getAnalytics(owner, providerId, "smart-fill", now.minus(1, ChronoUnit.DAYS),
                now.plus(1, ChronoUnit.DAYS));
        assertThat(inRange.get("campaignsCreated")).isEqualTo(1);

        Map<?, ?> wholeHistory = getAnalytics(owner, providerId, "smart-fill", now.minus(90, ChronoUnit.DAYS),
                now.plus(1, ChronoUnit.DAYS));
        assertThat(wholeHistory.get("campaignsCreated")).isEqualTo(2);
    }

    @Test
    void activeSmartFillCampaignsExcludesResolvedOnes() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-sfactive-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA SF Active Salon " + runId);
        Instant now = Instant.now();

        UUID activeSlotId = UUID.randomUUID();
        SmartFillCampaign active = new SmartFillCampaign(UUID.randomUUID(), providerId, UUID.randomUUID(), null,
                activeSlotId, UUID.randomUUID(), now.plus(1, ChronoUnit.DAYS),
                now.plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES), new BigDecimal("20.00"), "USD", now);
        smartFillCampaignRepository.save(active);

        // A real cancellation with no eligible candidates -- Smart Fill expires it immediately (see
        // SmartFillApiTests) -- must not appear in the active list.
        UUID serviceId = createService(owner, providerId, "SF Active Service " + runId, new BigDecimal("20.00"));
        Instant resolvedStart = now.plus(2, ChronoUnit.DAYS);
        UUID resolvedSlot = createSlot(owner, providerId, resolvedStart, resolvedStart.plus(30, ChronoUnit.MINUTES));
        Registered canceller = TestAuth.registerCustomer(restTemplate, "ba-sfactive-canceller-" + runId + "@example.com");
        UUID resolvedBookingId = bookWithPrice(canceller, serviceId, resolvedSlot, new BigDecimal("20.00"));
        cancelBooking(canceller, resolvedBookingId);

        ResponseEntity<List> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/analytics/smart-fill/active", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(1);
        Map<?, ?> campaign = (Map<?, ?>) response.getBody().get(0);
        assertThat(campaign.get("status")).isEqualTo("CREATED");
    }

    @Test
    void customerListFiltersByRetentionStatusAndOnlyTheOwnerCanReadIt() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "ba-custlist-owner-" + runId + "@example.com");
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "ba-custlist-other-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "BA Customer List Salon " + runId);
        UUID serviceId = createService(owner, providerId, "Overdue List Service " + runId, new BigDecimal("35.00"));

        // Same technique as CustomerIntelligenceApiTests / customerAnalyticsReportsRetentionMix...:
        // a 14-day cadence (visits 44 and 30 days ago) lands 30 days since the last visit -- past
        // atRiskFactor (2.0 x 14 = 28) but within inactiveFactor (3.0 x 14 = 42), so DUE_FOR_REBOOKING
        // or AT_RISK.
        Registered overdueCustomer = TestAuth.registerCustomer(restTemplate,
                "ba-custlist-overdue-" + runId + "@example.com");
        Instant today = Instant.now().truncatedTo(ChronoUnit.DAYS);
        completeVisit(owner, overdueCustomer, providerId, serviceId, today.minus(44, ChronoUnit.DAYS));
        completeVisit(owner, overdueCustomer, providerId, serviceId, today.minus(30, ChronoUnit.DAYS));

        ResponseEntity<Map> forbidden = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/analytics/customers/list", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())), Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<List> unfiltered = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/analytics/customers/list", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(unfiltered.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(unfiltered.getBody()).hasSize(1);
        Map<?, ?> customer = (Map<?, ?>) unfiltered.getBody().get(0);
        assertThat(customer.get("userId")).isEqualTo(overdueCustomer.userId().toString());
        assertThat(customer.get("favouriteServiceTitle")).isEqualTo("Overdue List Service " + runId);
        String actualStatus = (String) customer.get("retentionStatus");
        assertThat(actualStatus).isIn("DUE_FOR_REBOOKING", "AT_RISK");

        ResponseEntity<List> matchingFilter = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/analytics/customers/list?retentionStatus=" + actualStatus,
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(matchingFilter.getBody()).hasSize(1);

        ResponseEntity<List> nonMatchingFilter = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/analytics/customers/list?retentionStatus=ACTIVE",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), List.class);
        assertThat(nonMatchingFilter.getBody()).isEmpty();
    }

    private void completeVisit(Registered owner, Registered customer, UUID providerId, UUID serviceId,
            Instant startsAt) {
        UUID slotId = createSlot(owner, providerId, startsAt, startsAt.plus(30, ChronoUnit.MINUTES));
        UUID bookingId = bookWithPrice(customer, serviceId, slotId, new BigDecimal("35.00"));
        payBooking(customer, bookingId);
        completeBooking(owner, bookingId);
    }

    private Map<?, ?> getAnalytics(Registered owner, UUID providerId, String section, Instant from, Instant to) {
        ResponseEntity<Map> response = exchangeAnalytics(owner, providerId, section, from, to);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return response.getBody();
    }

    private ResponseEntity<Map> exchangeAnalytics(Registered owner, UUID providerId, String section, Instant from,
            Instant to) {
        UriComponentsBuilder uri = UriComponentsBuilder
                .fromPath("/api/v1/providers/" + providerId + "/analytics/" + section);
        if (from != null) {
            uri.queryParam("from", from.toString());
        }
        if (to != null) {
            uri.queryParam("to", to.toString());
        }
        return restTemplate.exchange(uri.toUriString(), HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
    }

    private void payBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/payments",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    private void completeBooking(Registered owner, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/complete",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
    }

    private void cancelBooking(Registered customer, UUID bookingId) {
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/bookings/" + bookingId + "/cancel",
                HttpMethod.POST, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        UUID providerId = UUID.fromString(response.getBody().get("id").toString());
        TestAuth.requireFullPayment(restTemplate, owner, providerId);
        return providerId;
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

}
