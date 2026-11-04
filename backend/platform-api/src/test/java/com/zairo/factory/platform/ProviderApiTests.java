package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.CredentialRepository;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderRequest;
import com.zairo.factory.providers.ProviderDtos.UpdateProviderStatusRequest;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.services.ServiceOfferingDtos.CreateServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.LinkCatalogServiceRequest;
import com.zairo.factory.services.ServiceOfferingDtos.UpdateServiceRequest;
import com.zairo.factory.users.UserRepository;
import java.math.BigDecimal;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * End-to-end check of the users -> providers -> services flow through real
 * HTTP + a real Postgres (Testcontainers), exercising Flyway migrations and
 * JPA mappings together rather than each module in isolation.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class ProviderApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CredentialRepository credentialRepository;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Test
    void createsOwnerThenProviderThenService() {
        Registered owner = TestAuth.registerOwner(restTemplate, "owner@example.com");
        UUID providerId = createProvider(owner, "Best Beauty Salon");

        var serviceRequest = new CreateServiceRequest("Haircut", 45, new BigDecimal("30.00"), "USD");
        ResponseEntity<Object> serviceResponse = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/services", HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(
                owner.accessToken())), Object.class);
        assertThat(serviceResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<Object[]> listResponse = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/services", Object[].class);
        assertThat(listResponse.getBody()).hasSize(1);
    }

    @Test
    void cannotCreateAProviderOrServiceForSomeoneElse() {
        Registered owner = TestAuth.registerOwner(restTemplate, "impersonation-owner@example.com");
        Registered attacker = TestAuth.registerOwner(restTemplate, "impersonation-attacker@example.com");

        // Claiming someone else as the owner, even while authenticated as yourself, is rejected.
        var spoofedRequest = new CreateProviderRequest(owner.userId(), "Spoofed Salon", "beauty");
        ResponseEntity<Object> spoofed = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(spoofedRequest, TestAuth.authHeaders(attacker.accessToken())), Object.class);
        assertThat(spoofed.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // No token at all is rejected too.
        var anonymousRequest = new CreateProviderRequest(owner.userId(), "Anonymous Salon", "beauty");
        ResponseEntity<Object> anonymous = restTemplate.postForEntity("/api/v1/providers", anonymousRequest,
                Object.class);
        assertThat(anonymous.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        UUID providerId = createProvider(owner, "Real Salon");

        // Attacker can't create a service under a provider they don't own either.
        var serviceRequest = new CreateServiceRequest("Haircut", 30, new BigDecimal("20.00"), "USD");
        ResponseEntity<Object> forbiddenService = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/services", HttpMethod.POST, new HttpEntity<>(serviceRequest, TestAuth.authHeaders(
                attacker.accessToken())), Object.class);
        assertThat(forbiddenService.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void updatesThenDeactivatesAService() {
        Registered owner = TestAuth.registerOwner(restTemplate, "service-edit-owner@example.com");
        UUID providerId = createProvider(owner, "Service Edit Salon");
        UUID serviceId = createService(owner, providerId, "Haircut", new BigDecimal("25.00"));

        var updateRequest = new UpdateServiceRequest("Haircut & Style", 45, new BigDecimal("35.00"), "USD");
        ResponseEntity<java.util.Map> updateResponse = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.PUT, new HttpEntity<>(updateRequest, TestAuth.authHeaders(owner.accessToken())),
                java.util.Map.class);
        assertThat(updateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updateResponse.getBody().get("title")).isEqualTo("Haircut & Style");
        assertThat(updateResponse.getBody().get("durationMinutes")).isEqualTo(45);

        // A different owner can't touch it — 403, not silently allowed.
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "service-edit-other-owner@example.com");
        ResponseEntity<java.util.Map> forbidden = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(otherOwner.accessToken())),
                java.util.Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<Void> deleteResponse = restTemplate.exchange("/api/v1/services/" + serviceId,
                HttpMethod.DELETE, new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<java.util.Map> afterDelete = restTemplate.getForEntity("/api/v1/services/" + serviceId,
                java.util.Map.class);
        assertThat(afterDelete.getBody().get("active")).isEqualTo(false);

        // Deactivating again (or a non-existent id) is a no-op, not an error.
        ResponseEntity<Void> deleteAgain = restTemplate.exchange("/api/v1/services/" + serviceId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
        assertThat(deleteAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // Deactivated services drop out of the default listing...
        assertThat(getServiceList(providerId, false)).isEmpty();
        // ...but are still visible (and reactivatable) with includeInactive=true.
        assertThat(getServiceList(providerId, true)).extracting(s -> s.get("id")).containsExactly(
                serviceId.toString());

        ResponseEntity<java.util.Map> reactivateResponse = restTemplate.exchange(
                "/api/v1/services/" + serviceId + "/reactivate", HttpMethod.POST,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(reactivateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(reactivateResponse.getBody().get("active")).isEqualTo(true);
        assertThat(getServiceList(providerId, false)).extracting(s -> s.get("id")).containsExactly(
                serviceId.toString());
    }

    @Test
    void catalogLinkRequiresOwnershipAndARealCatalogServiceId() {
        Registered owner = TestAuth.registerOwner(restTemplate, "catalog-link-owner@example.com");
        UUID providerId = createProvider(owner, "Catalog Link Salon");
        UUID serviceId = createService(owner, providerId, "Haircut", new BigDecimal("25.00"));

        // A different owner can't link it — 403.
        Registered otherOwner = TestAuth.registerOwner(restTemplate, "catalog-link-other-owner@example.com");
        ResponseEntity<java.util.Map> forbidden = restTemplate.exchange("/api/v1/services/" + serviceId
                + "/catalog-link", HttpMethod.PATCH, new HttpEntity<>(new LinkCatalogServiceRequest(null),
                TestAuth.authHeaders(otherOwner.accessToken())), java.util.Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // A non-existent catalog service id is rejected, not silently accepted.
        ResponseEntity<java.util.Map> notFound = restTemplate.exchange("/api/v1/services/" + serviceId
                + "/catalog-link", HttpMethod.PATCH, new HttpEntity<>(
                new LinkCatalogServiceRequest(UUID.randomUUID()), TestAuth.authHeaders(owner.accessToken())),
                java.util.Map.class);
        assertThat(notFound.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void updatesASalonsNameAndLocationButOnlyTheOwnerCan() {
        Registered owner = TestAuth.registerOwner(restTemplate, "salon-edit-owner@example.com");
        UUID providerId = createProvider(owner, "Original Salon Name");

        var updateRequest = new UpdateProviderRequest("Renamed Salon", 43.25, 76.90);
        ResponseEntity<java.util.Map> updateResponse = restTemplate.exchange("/api/v1/providers/" + providerId,
                HttpMethod.PUT, new HttpEntity<>(updateRequest, TestAuth.authHeaders(owner.accessToken())),
                java.util.Map.class);
        assertThat(updateResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updateResponse.getBody().get("name")).isEqualTo("Renamed Salon");
        assertThat(updateResponse.getBody().get("latitude")).isEqualTo(43.25);

        Registered otherOwner = TestAuth.registerOwner(restTemplate, "salon-edit-other-owner@example.com");
        ResponseEntity<java.util.Map> forbidden = restTemplate.exchange("/api/v1/providers/" + providerId,
                HttpMethod.PUT, new HttpEntity<>(updateRequest, TestAuth.authHeaders(otherOwner.accessToken())),
                java.util.Map.class);
        assertThat(forbidden.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void theOwnerPicksTheBusinessCityAndOmittingItKeepsIt() {
        Registered owner = TestAuth.registerOwner(restTemplate, "salon-city-owner-" + UUID.randomUUID()
                + "@example.com");
        UUID providerId = createProvider(owner, "City Salon");
        String path = "/api/v1/providers/" + providerId;

        assertThat(restTemplate.getForEntity(path, java.util.Map.class).getBody().get("cityCode")).isNull();

        ResponseEntity<java.util.Map> picked = restTemplate.exchange(path, HttpMethod.PUT, new HttpEntity<>(
                new UpdateProviderRequest("City Salon", 43.25, 76.90, null, "almaty"),
                TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(picked.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(picked.getBody().get("cityCode")).isEqualTo("almaty");

        // An edit that does not mention the city (an older app) keeps it.
        ResponseEntity<java.util.Map> renamed = restTemplate.exchange(path, HttpMethod.PUT, new HttpEntity<>(
                new UpdateProviderRequest("City Salon 2", 43.25, 76.90),
                TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(renamed.getBody().get("cityCode")).isEqualTo("almaty");

        // A city that does not exist is a 400, and the old one stays.
        ResponseEntity<java.util.Map> unknown = restTemplate.exchange(path, HttpMethod.PUT, new HttpEntity<>(
                new UpdateProviderRequest("City Salon 2", 43.25, 76.90, null, "no-such-city"),
                TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(unknown.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(restTemplate.getForEntity(path, java.util.Map.class).getBody().get("cityCode"))
                .isEqualTo("almaty");
    }

    @Test
    void theOwnerPublishesAddressPhoneDescriptionAndHoursAndOmittingThemKeepsThem() {
        Registered owner = TestAuth.registerOwner(restTemplate, "salon-profile-owner-" + UUID.randomUUID()
                + "@example.com");
        UUID providerId = createProvider(owner, "Profile Salon");
        String path = "/api/v1/providers/" + providerId;

        var hours = java.util.Map.of("mon", "09:00-20:00", "sat", "10:00-16:00");
        ResponseEntity<java.util.Map> saved = restTemplate.exchange(path, HttpMethod.PUT, new HttpEntity<>(
                new UpdateProviderRequest("Profile Salon", 43.25, 76.90, null, null, "Abay 10", "+7 701 000 00 00",
                        "Cosy place", hours), TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(saved.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(saved.getBody().get("address")).isEqualTo("Abay 10");
        assertThat(saved.getBody().get("phone")).isEqualTo("+7 701 000 00 00");
        assertThat(saved.getBody().get("description")).isEqualTo("Cosy place");
        assertThat((java.util.Map<String, String>) saved.getBody().get("workingHours")).containsEntry("mon", "09:00-20:00")
                .containsEntry("sat", "10:00-16:00").doesNotContainKey("tue");

        // An edit that does not mention them (an older app) keeps them.
        restTemplate.exchange(path, HttpMethod.PUT, new HttpEntity<>(
                new UpdateProviderRequest("Profile Salon 2", 43.25, 76.90),
                TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        var kept = restTemplate.getForEntity(path, java.util.Map.class).getBody();
        assertThat(kept.get("address")).isEqualTo("Abay 10");
        assertThat((java.util.Map<String, String>) kept.get("workingHours")).hasSize(2);

        // Blank clears the text fields, {} clears the hours.
        restTemplate.exchange(path, HttpMethod.PUT, new HttpEntity<>(
                new UpdateProviderRequest("Profile Salon 2", 43.25, 76.90, null, null, " ", "", "",
                        java.util.Map.of()), TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        var cleared = restTemplate.getForEntity(path, java.util.Map.class).getBody();
        assertThat(cleared.get("address")).isNull();
        assertThat(cleared.get("phone")).isNull();
        assertThat(cleared.get("description")).isNull();
        assertThat((java.util.Map<String, String>) cleared.get("workingHours")).isEmpty();
    }

    @Test
    void malformedWorkingHoursAreRejected() {
        Registered owner = TestAuth.registerOwner(restTemplate, "salon-hours-owner-" + UUID.randomUUID()
                + "@example.com");
        UUID providerId = createProvider(owner, "Hours Salon");
        for (var bad : java.util.List.of(java.util.Map.of("funday", "09:00-20:00"),
                java.util.Map.of("mon", "9-20"), java.util.Map.of("mon", "20:00-09:00"))) {
            ResponseEntity<java.util.Map> response = restTemplate.exchange("/api/v1/providers/" + providerId,
                    HttpMethod.PUT, new HttpEntity<>(new UpdateProviderRequest("Hours Salon", 43.25, 76.90, null,
                            null, null, null, null, bad), TestAuth.authHeaders(owner.accessToken())),
                    java.util.Map.class);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        }
    }

    @Test
    void aBusinessCreatedWithACityKeepsItAndAnUnknownCityIsRejected() {
        Registered owner = TestAuth.registerOwner(restTemplate, "salon-create-city-" + UUID.randomUUID()
                + "@example.com");
        // FREE allows one business per owner; this test creates a second (rejected) one too.
        TestAuth.upgradeToPro(restTemplate, owner);

        ResponseEntity<java.util.Map> created = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), "Almaty Salon", "beauty", null, null,
                        "almaty"), TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(created.getBody().get("cityCode")).isEqualTo("almaty");

        ResponseEntity<java.util.Map> unknown = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(new CreateProviderRequest(owner.userId(), "Nowhere Salon", "beauty", null, null,
                        "no-such-city"), TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(unknown.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void newProvidersStartPendingAndOnlyAnAdminCanModerateThem() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "moderation-owner-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Moderation Salon " + runId);

        ResponseEntity<java.util.Map> created = restTemplate.getForEntity("/api/v1/providers/" + providerId,
                java.util.Map.class);
        assertThat(created.getBody().get("status")).isEqualTo("PENDING");

        // Neither the owner nor an unauthenticated caller can moderate.
        var approveRequest = new UpdateProviderStatusRequest(ProviderStatus.ACTIVE);
        ResponseEntity<java.util.Map> ownerAttempt = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(approveRequest, TestAuth.authHeaders(
                owner.accessToken())), java.util.Map.class);
        assertThat(ownerAttempt.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        ResponseEntity<java.util.Map> anonymousAttempt = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(approveRequest), java.util.Map.class);
        assertThat(anonymousAttempt.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // Admin approves it.
        Registered admin = TestAuth.registerAdmin(restTemplate, userRepository, credentialRepository,
                "moderation-admin-" + runId + "@example.com");
        ResponseEntity<java.util.Map> approved = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(approveRequest, TestAuth.authHeaders(
                admin.accessToken())), java.util.Map.class);
        assertThat(approved.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(approved.getBody().get("status")).isEqualTo("ACTIVE");

        // Shows up in the PENDING filter before approval, not after. The
        // PENDING filter is moderation data — see
        // gettingProvidersByNonActiveStatusRequiresAPlatformRole — so this
        // read needs a platform token too, unlike the public ACTIVE one.
        var platformAdmin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "moderation-platform-admin-" + runId + "@factory.internal", PlatformRole.PLATFORM_ADMIN);
        assertThat(getProviderIdsByStatus(ProviderStatus.PENDING, platformAdmin)).doesNotContain(
                providerId.toString());
        assertThat(getProviderIdsByStatus(ProviderStatus.ACTIVE, null)).contains(providerId.toString());

        // Admin can also suspend it again.
        var suspendRequest = new UpdateProviderStatusRequest(ProviderStatus.SUSPENDED);
        ResponseEntity<java.util.Map> suspended = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/status", HttpMethod.PATCH, new HttpEntity<>(suspendRequest, TestAuth.authHeaders(
                admin.accessToken())), java.util.Map.class);
        assertThat(suspended.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(suspended.getBody().get("status")).isEqualTo("SUSPENDED");
    }

    /**
     * Proves the fix for GET /providers's missing authorization on non-ACTIVE
     * status filters (Security Audit follow-up, P2-1): a PENDING/SUSPENDED
     * listing is moderation data, so it now requires an authenticated
     * platform role (PLATFORM_ADMIN or PLATFORM_SUPPORT, same as GET
     * /platform/businesses) — a regular customer/owner bearer token doesn't
     * satisfy that role check at all, same 401-not-403 semantics as
     * PaymentsController.refund's own platform-only endpoint. The unfiltered
     * listing and ?status=ACTIVE stay exactly as public as before.
     */
    @Test
    void gettingProvidersByNonActiveStatusRequiresAPlatformRole() {
        String runId = UUID.randomUUID().toString();

        // No token at all -> 401 for a non-ACTIVE status.
        ResponseEntity<java.util.Map> unauthenticatedPending = restTemplate.getForEntity(
                "/api/v1/providers?status=PENDING", java.util.Map.class);
        assertThat(unauthenticatedPending.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<java.util.Map> unauthenticatedSuspended = restTemplate.getForEntity(
                "/api/v1/providers?status=SUSPENDED", java.util.Map.class);
        assertThat(unauthenticatedSuspended.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // A regular (non-platform) bearer token is not a platform access
        // token at all — same 401, not 403, as the fully anonymous case,
        // same reasoning as PaymentsController.refund's own coverage.
        Registered customer = TestAuth.registerCustomer(restTemplate, "providers-authz-cust-" + runId
                + "@example.com");
        ResponseEntity<java.util.Map> asCustomer = restTemplate.exchange("/api/v1/providers?status=PENDING",
                HttpMethod.GET, new HttpEntity<>(null, TestAuth.authHeaders(customer.accessToken())),
                java.util.Map.class);
        assertThat(asCustomer.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // PLATFORM_SUPPORT (read-only across the Control Center) can still read this listing.
        var support = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "providers-authz-support-" + runId + "@factory.internal", PlatformRole.PLATFORM_SUPPORT);
        ResponseEntity<java.util.Map[]> asSupport = restTemplate.exchange("/api/v1/providers?status=PENDING",
                HttpMethod.GET, new HttpEntity<>(null, TestPlatformAuth.authHeaders(support.accessToken())),
                java.util.Map[].class);
        assertThat(asSupport.getStatusCode()).isEqualTo(HttpStatus.OK);

        // PLATFORM_ADMIN can read it too.
        var admin = TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "providers-authz-admin-" + runId + "@factory.internal", PlatformRole.PLATFORM_ADMIN);
        ResponseEntity<java.util.Map[]> asAdmin = restTemplate.exchange("/api/v1/providers?status=PENDING",
                HttpMethod.GET, new HttpEntity<>(null, TestPlatformAuth.authHeaders(admin.accessToken())),
                java.util.Map[].class);
        assertThat(asAdmin.getStatusCode()).isEqualTo(HttpStatus.OK);

        // The unfiltered listing and ?status=ACTIVE stay exactly as public as before.
        ResponseEntity<java.util.Map[]> unauthenticatedUnfiltered = restTemplate.getForEntity("/api/v1/providers",
                java.util.Map[].class);
        assertThat(unauthenticatedUnfiltered.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<java.util.Map[]> unauthenticatedActive = restTemplate.getForEntity(
                "/api/v1/providers?status=ACTIVE", java.util.Map[].class);
        assertThat(unauthenticatedActive.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    /** {@code platformAdmin} is only needed (and only sent) for a non-ACTIVE status — see ProviderController.list. */
    private java.util.List<String> getProviderIdsByStatus(ProviderStatus status,
            TestPlatformAuth.Registered platformAdmin) {
        HttpHeaders headers = platformAdmin == null ? new HttpHeaders()
                : TestPlatformAuth.authHeaders(platformAdmin.accessToken());
        HttpEntity<Void> entity = new HttpEntity<>(null, headers);
        ResponseEntity<java.util.Map[]> response = restTemplate.exchange("/api/v1/providers?status=" + status,
                HttpMethod.GET, entity, java.util.Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return java.util.Arrays.stream(response.getBody()).map(p -> (String) p.get("id")).toList();
    }

    private java.util.List<java.util.Map> getServiceList(UUID providerId, boolean includeInactive) {
        ResponseEntity<java.util.Map[]> response = restTemplate.getForEntity(
                "/api/v1/providers/" + providerId + "/services?includeInactive=" + includeInactive,
                java.util.Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return java.util.List.of(response.getBody());
    }

    private UUID createProvider(Registered owner, String name) {
        var request = new CreateProviderRequest(owner.userId(), name, "beauty");
        ResponseEntity<java.util.Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), java.util.Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private UUID createService(Registered owner, UUID providerId, String title, BigDecimal price) {
        var request = new CreateServiceRequest(title, 30, price, "USD");
        ResponseEntity<java.util.Map> response = restTemplate.exchange("/api/v1/providers/" + providerId
                + "/services", HttpMethod.POST, new HttpEntity<>(request, TestAuth.authHeaders(
                owner.accessToken())), java.util.Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }
}
