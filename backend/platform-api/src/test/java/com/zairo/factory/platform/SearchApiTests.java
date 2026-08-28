package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.booking.AvailabilitySlotDtos.CreateAvailabilitySlotRequest;
import com.zairo.factory.booking.BookingDtos.CreateBookingRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.reviews.ReviewDtos.CreateReviewRequest;
import com.zairo.factory.search.SearchSort;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.LinkCatalogServiceRequest;
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
 * Against a real Postgres (Testcontainers): verifies vertical filtering,
 * text search across provider name / service title, and the deterministic
 * ranking (open availability first, then cheapest price).
 *
 * Spring's test context cache reuses the same ApplicationContext (and thus
 * the same Testcontainers Postgres + accumulated data) across every test
 * class with this exact same annotation set — ProviderApiTests,
 * BookingApiTests, ReviewApiTests all match. So this test uses a
 * random per-run vertical value (no collision with other tests' fixed
 * "beauty"/"auto" verticals) and containsSubsequence instead of
 * containsExactly for the unfiltered "all providers" case, since other
 * tests' providers are legitimately mixed in.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class SearchApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void pendingProvidersAreInvisibleToSearchUntilAnAdminApprovesThem() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-mod-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "mod-search-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Unapproved Salon " + runId, vertical);
        createService(owner, providerId, "Cut", new BigDecimal("10.00"));

        assertThat(search(vertical, null)).isEmpty();

        approve(providerId);

        assertThat(search(vertical, null)).extracting(r -> r.get("id")).containsExactly(providerId.toString());
    }

    @Test
    void filtersByVerticalAndQueryAndRanksByAvailabilityThenPrice() {
        String runId = UUID.randomUUID().toString();
        String verticalBeauty = "beauty-" + runId;
        String verticalAuto = "auto-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "search-owner-" + runId + "@example.com");
        // FREE only allows one provider per owner — these search tests need
        // several providers under the same owner to compare ranking, which
        // is unrelated to plan limits (covered separately by SubscriptionApiTests).
        TestAuth.upgradeToPro(restTemplate, owner);

        UUID providerA = createProvider(owner, "Hair Studio A " + runId, verticalBeauty);
        createService(owner, providerA, "Haircut", new BigDecimal("30.00"));
        createOpenSlot(owner, providerA);
        approve(providerA);

        UUID providerB = createProvider(owner, "Beauty Bar B " + runId, verticalBeauty);
        createService(owner, providerB, "Massage", new BigDecimal("20.00"));
        // no availability slot for B
        approve(providerB);

        UUID providerC = createProvider(owner, "Quick Lube C " + runId, verticalAuto);
        createService(owner, providerC, "Oil change", new BigDecimal("15.00"));
        // no availability slot for C
        approve(providerC);

        List<Map> beautyResults = search(verticalBeauty, null);
        assertThat(beautyResults).extracting(r -> r.get("id"))
                .containsExactlyInAnyOrder(providerA.toString(), providerB.toString());
        // A has open availability, so it ranks first despite being pricier.
        assertThat(beautyResults.get(0).get("id")).isEqualTo(providerA.toString());

        List<Map> hairQuery = search(verticalBeauty, "hair");
        assertThat(hairQuery).extracting(r -> r.get("id")).containsExactly(providerA.toString());

        List<Map> allResults = search(null, null);
        assertThat(allResults).extracting(r -> r.get("id")).containsSubsequence(providerA.toString(),
                providerC.toString(), providerB.toString());
    }

    @Test
    void ranksByDistanceWhenTheCallerSuppliesItsLocation() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-dist-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "dist-owner-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);

        // Almaty city center as the search origin.
        double originLat = 43.2389;
        double originLng = 76.8897;

        // Near: a few km away.
        UUID providerNear = createProvider(owner, "Near Salon " + runId, vertical, 43.25, 76.90);
        createService(owner, providerNear, "Cut", new BigDecimal("20.00"));
        createOpenSlot(owner, providerNear);
        approve(providerNear);

        // Far: a different city entirely (Astana), hundreds of km away.
        UUID providerFar = createProvider(owner, "Far Salon " + runId, vertical, 51.1694, 71.4491);
        createService(owner, providerFar, "Cut", new BigDecimal("20.00"));
        createOpenSlot(owner, providerFar);
        approve(providerFar);

        List<Map> results = search(vertical, null, originLat, originLng);
        assertThat(results).extracting(r -> r.get("id")).containsExactly(providerNear.toString(),
                providerFar.toString());
        double nearDistance = ((Number) results.get(0).get("distanceKm")).doubleValue();
        double farDistance = ((Number) results.get(1).get("distanceKm")).doubleValue();
        assertThat(nearDistance).isLessThan(farDistance);
    }

    @Test
    void filtersByPriceRangeAndAvailability() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-price-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "price-owner-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);

        UUID cheapAvailable = createProvider(owner, "Cheap Available " + runId, vertical);
        createService(owner, cheapAvailable, "Cut", new BigDecimal("10.00"));
        createOpenSlot(owner, cheapAvailable);
        approve(cheapAvailable);

        UUID midNoSlot = createProvider(owner, "Mid No Slot " + runId, vertical);
        createService(owner, midNoSlot, "Cut", new BigDecimal("25.00"));
        approve(midNoSlot);

        UUID expensive = createProvider(owner, "Expensive " + runId, vertical);
        createService(owner, expensive, "Cut", new BigDecimal("60.00"));
        approve(expensive);

        // Price range [15, 30] only matches the mid-priced one.
        List<Map> priceFiltered = search(new SearchParams(vertical).minPrice(new BigDecimal("15.00"))
                .maxPrice(new BigDecimal("30.00")));
        assertThat(priceFiltered).extracting(r -> r.get("id")).containsExactly(midNoSlot.toString());

        // availableOnly excludes the two without an open slot.
        List<Map> availableOnly = search(new SearchParams(vertical).availableOnly(true));
        assertThat(availableOnly).extracting(r -> r.get("id")).containsExactly(cheapAvailable.toString());
    }

    @Test
    void sortsByPriceAscDescAndDistance() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-sort-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "sort-owner-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);

        double originLat = 43.2389;
        double originLng = 76.8897;

        UUID cheapFar = createProvider(owner, "Cheap Far " + runId, vertical, 51.1694, 71.4491);
        createService(owner, cheapFar, "Cut", new BigDecimal("10.00"));
        approve(cheapFar);

        UUID expensiveNear = createProvider(owner, "Expensive Near " + runId, vertical, 43.25, 76.90);
        createService(owner, expensiveNear, "Cut", new BigDecimal("50.00"));
        approve(expensiveNear);

        List<Map> priceAsc = search(new SearchParams(vertical).sort(SearchSort.PRICE_ASC));
        assertThat(priceAsc).extracting(r -> r.get("id")).containsExactly(cheapFar.toString(),
                expensiveNear.toString());

        List<Map> priceDesc = search(new SearchParams(vertical).sort(SearchSort.PRICE_DESC));
        assertThat(priceDesc).extracting(r -> r.get("id")).containsExactly(expensiveNear.toString(),
                cheapFar.toString());

        List<Map> byDistance = search(
                new SearchParams(vertical).lat(originLat).lng(originLng).sort(SearchSort.DISTANCE));
        assertThat(byDistance).extracting(r -> r.get("id")).containsExactly(expensiveNear.toString(),
                cheapFar.toString());

        // maxDistanceKm excludes the far one once a location is supplied.
        List<Map> withinRange = search(
                new SearchParams(vertical).lat(originLat).lng(originLng).maxDistanceKm(50.0));
        assertThat(withinRange).extracting(r -> r.get("id")).containsExactly(expensiveNear.toString());
    }

    @Test
    void surfacesAverageRatingAndReviewCountAndSupportsRatingFilterAndSort() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-rating-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "rating-owner-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);

        UUID wellRated = createProvider(owner, "Well Rated " + runId, vertical);
        createService(owner, wellRated, "Cut", new BigDecimal("20.00"));
        reviewProviderWithBooking(owner, wellRated, 5);
        reviewProviderWithBooking(owner, wellRated, 4);
        approve(wellRated);

        UUID poorlyRated = createProvider(owner, "Poorly Rated " + runId, vertical);
        createService(owner, poorlyRated, "Cut", new BigDecimal("20.00"));
        reviewProviderWithBooking(owner, poorlyRated, 2);
        approve(poorlyRated);

        UUID unrated = createProvider(owner, "Unrated " + runId, vertical);
        createService(owner, unrated, "Cut", new BigDecimal("20.00"));
        approve(unrated);

        List<Map> all = search(new SearchParams(vertical));
        Map wellRatedResult = all.stream().filter(r -> r.get("id").equals(wellRated.toString())).findFirst()
                .orElseThrow();
        assertThat(((Number) wellRatedResult.get("averageRating")).doubleValue()).isEqualTo(4.5);
        assertThat(((Number) wellRatedResult.get("reviewCount")).longValue()).isEqualTo(2L);
        Map unratedResult = all.stream().filter(r -> r.get("id").equals(unrated.toString())).findFirst()
                .orElseThrow();
        assertThat(unratedResult.get("averageRating")).isNull();

        // Rating sort: highest average first, unrated providers sort last.
        List<Map> byRating = search(new SearchParams(vertical).sort(SearchSort.RATING));
        assertThat(byRating).extracting(r -> r.get("id")).containsExactly(wellRated.toString(),
                poorlyRated.toString(), unrated.toString());

        // minRating excludes the poorly-rated and unrated providers.
        List<Map> minRatingFiltered = search(new SearchParams(vertical).minRating(4.0));
        assertThat(minRatingFiltered).extracting(r -> r.get("id")).containsExactly(wellRated.toString());
    }

    @Test
    void filtersByBusinessTypeIdMoreSpecificallyThanVertical() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "btype-owner-" + runId + "@example.com");
        // A literal "beauty" vertical (not a randomized one) so provider
        // creation resolves a real businessTypeId from the V25 seed — see
        // ProviderController.create.
        UUID providerId = createProvider(owner, "BType Salon " + runId, "beauty");
        createService(owner, providerId, "Cut", new BigDecimal("10.00"));
        approve(providerId);

        ResponseEntity<Map> providerResponse = restTemplate.getForEntity("/api/v1/providers/" + providerId,
                Map.class);
        UUID businessTypeId = UUID.fromString((String) providerResponse.getBody().get("businessTypeId"));

        List<Map> results = search(new SearchParams(null).businessTypeId(businessTypeId));
        assertThat(results).extracting(r -> r.get("id")).contains(providerId.toString());
    }

    @Test
    void findsAProviderByALinkedCatalogServicesNameInAnotherLanguage() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "catq-owner-" + runId + "@example.com");
        TestPlatformAuth.Registered admin = TestPlatformAuth.registerPlatformAdmin(restTemplate,
                platformAdminAccountRepository, "catq-admin-" + runId + "@factory.internal",
                PlatformRole.PLATFORM_ADMIN);

        UUID catalogServiceId = createCatalogService(admin, runId, "Distinctive Wax Treatment " + runId);

        UUID providerId = createProvider(owner, "Unrelated Salon Name " + runId, "beauty-catq-" + runId);
        UUID serviceId = createServiceReturningId(owner, providerId, "Обычный маникюр " + runId,
                new BigDecimal("15.00"));
        approve(providerId);

        // Not findable by the catalog name before linking.
        assertThat(search(new SearchParams(null).q("Distinctive Wax Treatment " + runId)))
                .extracting(r -> r.get("id")).doesNotContain(providerId.toString());

        ResponseEntity<Map> linkResponse = restTemplate.exchange("/api/v1/services/" + serviceId + "/catalog-link",
                HttpMethod.PATCH, new HttpEntity<>(new LinkCatalogServiceRequest(catalogServiceId),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(linkResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // Findable by the catalog entry's name, even though it shares no
        // words with the offering's own Russian title.
        List<Map> results = search(new SearchParams(null).q("Distinctive Wax Treatment " + runId));
        assertThat(results).extracting(r -> r.get("id")).contains(providerId.toString());
    }

    @Test
    void nextAvailableSlotIsTheEarliestOpenOne() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-next-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "next-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Next Slot Salon " + runId, vertical);
        createService(owner, providerId, "Cut", new BigDecimal("10.00"));
        approve(providerId);

        Instant later = Instant.now().plus(3, ChronoUnit.DAYS);
        Instant sooner = Instant.now().plus(1, ChronoUnit.DAYS);
        createSlot(owner, providerId, later, later.plus(30, ChronoUnit.MINUTES));
        createSlot(owner, providerId, sooner, sooner.plus(30, ChronoUnit.MINUTES));

        List<Map> results = search(vertical, null);
        assertThat(results).hasSize(1);
        String nextAvailableSlot = (String) results.get(0).get("nextAvailableSlot");
        assertThat(Instant.parse(nextAvailableSlot)).isCloseTo(sooner, org.assertj.core.api.Assertions
                .within(1, ChronoUnit.SECONDS));
    }

    @Test
    void filtersByCatalogServiceId() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "catfilter-owner-" + runId + "@example.com");
        // Two providers under one owner needs PRO — same reasoning as every
        // other multi-provider search test in this file.
        TestAuth.upgradeToPro(restTemplate, owner);
        TestPlatformAuth.Registered admin = TestPlatformAuth.registerPlatformAdmin(restTemplate,
                platformAdminAccountRepository, "catfilter-admin-" + runId + "@factory.internal",
                PlatformRole.PLATFORM_ADMIN);
        UUID catalogServiceId = createCatalogService(admin, runId, "Filterable Service " + runId);

        UUID linkedProvider = createProvider(owner, "Linked Provider " + runId, "beauty-cf-" + runId);
        UUID linkedService = createServiceReturningId(owner, linkedProvider, "Something " + runId,
                new BigDecimal("10.00"));
        approve(linkedProvider);
        restTemplate.exchange("/api/v1/services/" + linkedService + "/catalog-link", HttpMethod.PATCH,
                new HttpEntity<>(new LinkCatalogServiceRequest(catalogServiceId),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);

        UUID unlinkedProvider = createProvider(owner, "Unlinked Provider " + runId, "beauty-cf-" + runId);
        createService(owner, unlinkedProvider, "Something Else " + runId, new BigDecimal("10.00"));
        approve(unlinkedProvider);

        List<Map> results = search(new SearchParams(null).catalogServiceId(catalogServiceId));
        assertThat(results).extracting(r -> r.get("id")).contains(linkedProvider.toString())
                .doesNotContain(unlinkedProvider.toString());
    }

    @Test
    void paginatesResultsAndExposesTotalCountHeader() {
        String runId = UUID.randomUUID().toString();
        String vertical = "beauty-page-" + runId;
        Registered owner = TestAuth.registerOwner(restTemplate, "page-owner-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);

        UUID providerA = createProvider(owner, "Page A " + runId, vertical);
        createService(owner, providerA, "Cut", new BigDecimal("10.00"));
        approve(providerA);
        UUID providerB = createProvider(owner, "Page B " + runId, vertical);
        createService(owner, providerB, "Cut", new BigDecimal("10.00"));
        approve(providerB);
        UUID providerC = createProvider(owner, "Page C " + runId, vertical);
        createService(owner, providerC, "Cut", new BigDecimal("10.00"));
        approve(providerC);

        ResponseEntity<Map[]> firstPage = searchResponse(new SearchParams(vertical).page(0).size(2));
        assertThat(firstPage.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(firstPage.getBody()).hasSize(2);
        assertThat(firstPage.getHeaders().getFirst("X-Total-Count")).isEqualTo("3");

        ResponseEntity<Map[]> secondPage = searchResponse(new SearchParams(vertical).page(1).size(2));
        assertThat(secondPage.getBody()).hasSize(1);
        assertThat(secondPage.getHeaders().getFirst("X-Total-Count")).isEqualTo("3");
    }

    /** Category -> BusinessType -> CatalogService, all fresh for this run, PLATFORM_ADMIN-created. */
    private UUID createCatalogService(TestPlatformAuth.Registered admin, String runId, String catalogServiceName) {
        String suffix = runId.replace("-", "");
        Map<String, Object> categoryRequest = Map.of("code", "catq_cat_" + suffix, "nameKk", "Т", "nameRu", "Т",
                "nameEn", "T", "sortOrder", 1);
        Map<?, ?> category = restTemplate.exchange("/api/v1/platform/categories", HttpMethod.POST,
                new HttpEntity<>(categoryRequest, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class)
                .getBody();

        Map<String, Object> businessTypeRequest = Map.of("categoryId", category.get("id"), "code",
                "catq_bt_" + suffix, "nameKk", "Т", "nameRu", "Т", "nameEn", "T", "sortOrder", 1);
        Map<?, ?> businessType = restTemplate.exchange("/api/v1/platform/business-types", HttpMethod.POST,
                new HttpEntity<>(businessTypeRequest, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class)
                .getBody();

        Map<String, Object> serviceRequest = Map.of("businessTypeId", businessType.get("id"), "nameKk",
                catalogServiceName, "nameRu", catalogServiceName, "nameEn", catalogServiceName, "sortOrder", 1);
        Map<?, ?> catalogService = restTemplate.exchange("/api/v1/platform/services", HttpMethod.POST,
                new HttpEntity<>(serviceRequest, TestPlatformAuth.authHeaders(admin.accessToken())), Map.class)
                .getBody();
        return UUID.fromString((String) catalogService.get("id"));
    }

    /** Books, completes, and leaves a review for a fresh customer against the given provider's one service. */
    private void reviewProviderWithBooking(Registered owner, UUID providerId, int rating) {
        Registered customer = TestAuth.registerCustomer(restTemplate,
                "rating-customer-" + UUID.randomUUID() + "@example.com");
        UUID customerId = customer.userId();
        UUID serviceId = UUID.fromString(((Map) restTemplate
                .getForEntity("/api/v1/providers/" + providerId + "/services", Map[].class).getBody()[0]).get("id")
                .toString());
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS).plus((long) (Math.random() * 1000), ChronoUnit.HOURS);
        UUID slotId = createSlot(owner, providerId, start, start.plus(30, ChronoUnit.MINUTES));

        var bookingRequest = new CreateBookingRequest(customerId, serviceId, slotId, new BigDecimal("20.00"));
        Map<?, ?> booking = restTemplate.exchange("/api/v1/bookings", HttpMethod.POST,
                new HttpEntity<>(bookingRequest, TestAuth.authHeaders(customer.accessToken())), Map.class).getBody();
        UUID bookingId = UUID.fromString(booking.get("id").toString());

        // Completing requires CONFIRMED first, which requires payment (ADR-0006).
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/payments", null, Map.class);
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/complete", null, Map.class);
        restTemplate.postForEntity("/api/v1/bookings/" + bookingId + "/reviews", new CreateReviewRequest(rating, null),
                Map.class);
    }

    private List<Map> search(String vertical, String q) {
        return search(new SearchParams(vertical).q(q));
    }

    private List<Map> search(String vertical, String q, Double lat, Double lng) {
        return search(new SearchParams(vertical).q(q).lat(lat).lng(lng));
    }

    /** Mutable query-param builder — the search endpoint has too many optional filters for positional args. */
    private static final class SearchParams {
        private final String vertical;
        private UUID businessTypeId;
        private UUID catalogServiceId;
        private String q;
        private Double lat;
        private Double lng;
        private BigDecimal minPrice;
        private BigDecimal maxPrice;
        private Double maxDistanceKm;
        private Double minRating;
        private boolean availableOnly;
        private SearchSort sort;
        private Integer page;
        private Integer size;

        SearchParams(String vertical) {
            this.vertical = vertical;
        }

        SearchParams q(String q) {
            this.q = q;
            return this;
        }

        SearchParams businessTypeId(UUID businessTypeId) {
            this.businessTypeId = businessTypeId;
            return this;
        }

        SearchParams lat(Double lat) {
            this.lat = lat;
            return this;
        }

        SearchParams lng(Double lng) {
            this.lng = lng;
            return this;
        }

        SearchParams minPrice(BigDecimal minPrice) {
            this.minPrice = minPrice;
            return this;
        }

        SearchParams maxPrice(BigDecimal maxPrice) {
            this.maxPrice = maxPrice;
            return this;
        }

        SearchParams maxDistanceKm(Double maxDistanceKm) {
            this.maxDistanceKm = maxDistanceKm;
            return this;
        }

        SearchParams minRating(Double minRating) {
            this.minRating = minRating;
            return this;
        }

        SearchParams availableOnly(boolean availableOnly) {
            this.availableOnly = availableOnly;
            return this;
        }

        SearchParams sort(SearchSort sort) {
            this.sort = sort;
            return this;
        }

        SearchParams catalogServiceId(UUID catalogServiceId) {
            this.catalogServiceId = catalogServiceId;
            return this;
        }

        SearchParams page(int page) {
            this.page = page;
            return this;
        }

        SearchParams size(int size) {
            this.size = size;
            return this;
        }
    }

    private List<Map> search(SearchParams params) {
        StringBuilder url = new StringBuilder("/api/v1/search/providers?");
        if (params.vertical != null) {
            url.append("vertical=").append(params.vertical).append("&");
        }
        if (params.businessTypeId != null) {
            url.append("businessTypeId=").append(params.businessTypeId).append("&");
        }
        if (params.catalogServiceId != null) {
            url.append("catalogServiceId=").append(params.catalogServiceId).append("&");
        }
        if (params.q != null) {
            url.append("q=").append(params.q).append("&");
        }
        if (params.lat != null && params.lng != null) {
            url.append("lat=").append(params.lat).append("&lng=").append(params.lng).append("&");
        }
        if (params.minPrice != null) {
            url.append("minPrice=").append(params.minPrice).append("&");
        }
        if (params.maxPrice != null) {
            url.append("maxPrice=").append(params.maxPrice).append("&");
        }
        if (params.maxDistanceKm != null) {
            url.append("maxDistanceKm=").append(params.maxDistanceKm).append("&");
        }
        if (params.minRating != null) {
            url.append("minRating=").append(params.minRating).append("&");
        }
        if (params.availableOnly) {
            url.append("availableOnly=true&");
        }
        if (params.sort != null) {
            url.append("sort=").append(params.sort).append("&");
        }
        if (params.page != null) {
            url.append("page=").append(params.page).append("&");
        }
        if (params.size != null) {
            url.append("size=").append(params.size).append("&");
        }
        ResponseEntity<Map[]> response = restTemplate.getForEntity(url.toString(), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private ResponseEntity<Map[]> searchResponse(SearchParams params) {
        StringBuilder url = new StringBuilder("/api/v1/search/providers?");
        if (params.vertical != null) {
            url.append("vertical=").append(params.vertical).append("&");
        }
        if (params.page != null) {
            url.append("page=").append(params.page).append("&");
        }
        if (params.size != null) {
            url.append("size=").append(params.size).append("&");
        }
        return restTemplate.getForEntity(url.toString(), Map[].class);
    }

    private UUID createProvider(Registered owner, String name, String vertical) {
        var request = new CreateProviderRequest(owner.userId(), name, vertical);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createProvider(Registered owner, String name, String vertical, double latitude, double longitude) {
        var request = new CreateProviderRequest(owner.userId(), name, vertical, latitude, longitude);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private void createService(Registered owner, UUID providerId, String title, BigDecimal price) {
        createServiceReturningId(owner, providerId, title, price);
    }

    private UUID createServiceReturningId(Registered owner, UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/services",
                HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    /** Search only ever surfaces ACTIVE providers — every provider a test wants findable must go through this. */
    private void approve(UUID providerId) {
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "search-admin-" + UUID.randomUUID() + "@example.com");
        var request = new UpdateProviderStatusRequest(ProviderStatus.ACTIVE);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers/" + providerId + "/status",
                HttpMethod.PATCH, new HttpEntity<>(request, TestAuth.authHeaders(admin.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private UUID createSlot(Registered owner, UUID providerId, Instant startsAt, Instant endsAt) {
        var request = new CreateAvailabilitySlotRequest(startsAt, endsAt);
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private void createOpenSlot(Registered owner, UUID providerId) {
        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        var request = new CreateAvailabilitySlotRequest(start, start.plus(30, ChronoUnit.MINUTES));
        ResponseEntity<Map> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/availability-slots", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }
}
