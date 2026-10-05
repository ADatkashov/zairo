package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.RequestPhoneOtpRequest;
import com.zairo.factory.auth.AuthDtos.VerifyPhoneOtpRequest;
import com.zairo.factory.invitations.InvitationDtos.CreateInvitationRequest;
import com.zairo.factory.platform.TestAuth.Registered;
import com.zairo.factory.providers.ProviderDtos.CreateProviderRequest;
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
 * Against a real Postgres (Testcontainers): staff invitations — an owner invites a phone number with no
 * account yet, and when that number is verified by SMS the person is attached to the business — plus the
 * phone lookup used to add people who are already registered.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        // Same OTP relaxations as IdentityApiTests: no resend cooldown or hourly caps between calls.
        properties = {"app.otp.resend-cooldown-seconds=0", "app.otp.max-requests-per-ip-per-hour=100000",
                "app.otp.daily-send-cap=1000000"})
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestIdentityProviders.class})
class InvitationsApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestIdentityProviders.CapturedOtps capturedOtps;

    @Test
    void invitedPersonJoinsAsStaffWhenTheyVerifyTheirPhone() {
        String runId = UUID.randomUUID().toString();
        OwnerWithProvider owner = ownerWithProvider("inv-staff-" + runId, "medicine_dental");
        UUID providerId = owner.providerId();
        String phone = uniqueKzPhone();

        ResponseEntity<Map> invited = invite(owner.registered(), providerId, phone);
        assertThat(invited.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(invited.getBody().get("kind")).isEqualTo("STAFF");
        assertThat(invited.getBody().get("status")).isEqualTo("PENDING");
        assertThat(invited.getBody().get("phone")).isEqualTo(phone);
        assertThat(listPending(owner.registered(), providerId)).hasSize(1);
        assertThat(getList("/api/v1/providers/" + providerId + "/staff")).isEmpty();

        signUpWithPhone(phone);

        List<Map> staff = getList("/api/v1/providers/" + providerId + "/staff");
        assertThat(staff).hasSize(1);
        assertThat(staff.get(0).get("displayName")).isEqualTo(phone);
        assertThat(listPending(owner.registered(), providerId)).isEmpty();
    }

    @Test
    void invitationKindFollowsTheBusinessVertical() {
        String runId = UUID.randomUUID().toString();
        Registered beauty = TestAuth.registerOwner(restTemplate, "inv-beauty-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, beauty);
        UUID beautyProvider = createProvider(beauty, "Salon " + runId, "beauty");
        Registered auto = TestAuth.registerOwner(restTemplate, "inv-auto-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, auto);
        UUID autoProvider = createProvider(auto, "Workshop " + runId, "auto");
        Registered cleaning = TestAuth.registerOwner(restTemplate, "inv-clean-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, cleaning);
        UUID cleaningProvider = createProvider(cleaning, "Cleaners " + runId, "cleaning");

        assertThat(invite(beauty, beautyProvider, uniqueKzPhone()).getBody().get("kind")).isEqualTo("MASTER");
        assertThat(invite(auto, autoProvider, uniqueKzPhone()).getBody().get("kind")).isEqualTo("MECHANIC");
        assertThat(invite(cleaning, cleaningProvider, uniqueKzPhone()).getBody().get("kind"))
                .isEqualTo("CLEANER");
    }

    @Test
    void invitedPersonBecomesAMasterAtABeautyBusiness() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-master-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);
        UUID providerId = createProvider(owner, "Glow " + runId, "beauty");
        String phone = uniqueKzPhone();

        assertThat(invite(owner, providerId, phone).getStatusCode()).isEqualTo(HttpStatus.CREATED);
        signUpWithPhone(phone);

        List<Map> masters = getList("/api/v1/beauty/providers/" + providerId + "/masters");
        assertThat(masters).hasSize(1);
        assertThat(masters.get(0).get("displayName")).isEqualTo(phone);
    }

    @Test
    void phoneIsNormalizedSoAnyCommonFormatMatchesTheVerifiedNumber() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-format-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);
        UUID providerId = createProvider(owner, "Format Clinic " + runId, "medicine_dental");
        String phone = uniqueKzPhone();
        String spaced = phone.substring(0, 2) + " " + phone.substring(2, 5) + " " + phone.substring(5, 8) + " "
                + phone.substring(8);

        ResponseEntity<Map> invited = invite(owner, providerId, spaced);

        assertThat(invited.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(invited.getBody().get("phone")).isEqualTo(phone);
    }

    @Test
    void invitingTheSameNumberTwiceIsRejectedButItCanBeReinvitedAfterCancelling() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-dup-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);
        UUID providerId = createProvider(owner, "Dup Clinic " + runId, "medicine_dental");
        String phone = uniqueKzPhone();

        ResponseEntity<Map> first = invite(owner, providerId, phone);
        assertThat(first.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(invite(owner, providerId, phone).getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

        cancel(owner, first.getBody().get("id").toString());
        assertThat(invite(owner, providerId, phone).getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void aCancelledInvitationDoesNotAttachAnyone() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-cancel-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);
        UUID providerId = createProvider(owner, "Cancel Clinic " + runId, "medicine_dental");
        String phone = uniqueKzPhone();
        String invitationId = invite(owner, providerId, phone).getBody().get("id").toString();

        ResponseEntity<Void> cancelled = cancel(owner, invitationId);
        assertThat(cancelled.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        // Idempotent.
        assertThat(cancel(owner, invitationId).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(listPending(owner, providerId)).isEmpty();

        signUpWithPhone(phone);

        assertThat(getList("/api/v1/providers/" + providerId + "/staff")).isEmpty();
    }

    @Test
    void onlyTheBusinessOwnerCanInviteListOrCancel() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-own-" + runId + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);
        UUID providerId = createProvider(owner, "Owned Clinic " + runId, "medicine_dental");
        Registered stranger = TestAuth.registerOwner(restTemplate, "inv-stranger-" + runId + "@example.com");
        String invitationId = invite(owner, providerId, uniqueKzPhone()).getBody().get("id").toString();

        assertThat(invite(stranger, providerId, uniqueKzPhone()).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(restTemplate.exchange("/api/v1/providers/" + providerId + "/staff-invitations", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(stranger.accessToken())), String.class)
                .getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(cancel(stranger, invitationId).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(listPending(owner, providerId)).hasSize(1);
    }

    @Test
    void anInvalidPhoneIsRejected() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-bad-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Bad Phone Clinic " + runId, "medicine_dental");

        assertThat(invite(owner, providerId, "not-a-phone").getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void anInvitationThatCannotBeFulfilledIsMarkedFailedAndNeverBlocksSignIn() {
        String runId = UUID.randomUUID().toString();
        // FREE plan allows 3 staff per business: the 4th invited person signs up fine but is not attached.
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-limit-" + runId + "@example.com");
        UUID providerId = createProvider(owner, "Limit Clinic " + runId, "medicine_dental");
        List<String> phones = List.of(uniqueKzPhone(), uniqueKzPhone(), uniqueKzPhone(), uniqueKzPhone());
        for (String phone : phones) {
            assertThat(invite(owner, providerId, phone).getStatusCode()).isEqualTo(HttpStatus.CREATED);
        }

        ResponseEntity<Map> last = null;
        for (String phone : phones) {
            last = signUpWithPhone(phone);
        }

        assertThat(last.getBody().get("accessToken")).isNotNull();
        assertThat(getList("/api/v1/providers/" + providerId + "/staff")).hasSize(3);
        // The refused one is no longer pending (it is marked failed), so it isn't offered for cancelling.
        assertThat(listPending(owner, providerId)).isEmpty();
    }

    // ---- phone lookup -----------------------------------------------------------------------------------

    @Test
    void aRegisteredPersonIsFoundByPhoneInAnyFormatAndOnlyBasicsAreReturned() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-lookup-" + runId + "@example.com");
        String phone = uniqueKzPhone();
        Map<?, ?> signedUp = signUpWithPhone(phone).getBody();
        String userId = ((Map<?, ?>) signedUp.get("user")).get("id").toString();
        String spaced = phone.substring(0, 2) + " " + phone.substring(2, 5) + " " + phone.substring(5, 8) + " "
                + phone.substring(8);

        for (String typed : List.of(phone, spaced)) {
            ResponseEntity<Map> found = lookup(owner, typed);
            assertThat(found.getStatusCode()).isEqualTo(HttpStatus.OK);
            assertThat(found.getBody().get("id")).isEqualTo(userId);
            assertThat(found.getBody()).containsOnlyKeys("id", "displayName", "avatarUrl");
        }
    }

    @Test
    void lookupOfAnUnregisteredPhoneIs404AndRequiresSignIn() {
        String runId = UUID.randomUUID().toString();
        Registered owner = TestAuth.registerOwner(restTemplate, "inv-lookup404-" + runId + "@example.com");

        assertThat(lookup(owner, uniqueKzPhone()).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(restTemplate.getForEntity("/api/v1/users/lookup?phone={p}", String.class, uniqueKzPhone())
                .getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    // ---- helpers ----------------------------------------------------------------------------------------

    private record OwnerWithProvider(Registered registered, UUID providerId) {
    }

    private OwnerWithProvider ownerWithProvider(String emailPrefix, String vertical) {
        Registered owner = TestAuth.registerOwner(restTemplate, emailPrefix + "@example.com");
        TestAuth.upgradeToPro(restTemplate, owner);
        return new OwnerWithProvider(owner, createProvider(owner, "Business " + emailPrefix, vertical));
    }

    private UUID createProvider(Registered owner, String name, String vertical) {
        var request = new CreateProviderRequest(owner.userId(), name, vertical);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/providers", HttpMethod.POST,
                new HttpEntity<>(request, TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return UUID.fromString(response.getBody().get("id").toString());
    }

    private ResponseEntity<Map> invite(Registered owner, UUID providerId, String phone) {
        return restTemplate.exchange("/api/v1/providers/" + providerId + "/staff-invitations", HttpMethod.POST,
                new HttpEntity<>(new CreateInvitationRequest(phone), TestAuth.authHeaders(owner.accessToken())),
                Map.class);
    }

    private List<Map> listPending(Registered owner, UUID providerId) {
        ResponseEntity<Map[]> response = restTemplate.exchange(
                "/api/v1/providers/" + providerId + "/staff-invitations", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private ResponseEntity<Void> cancel(Registered owner, String invitationId) {
        return restTemplate.exchange("/api/v1/staff-invitations/" + invitationId, HttpMethod.DELETE,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Void.class);
    }

    private ResponseEntity<Map> lookup(Registered caller, String phone) {
        return restTemplate.exchange("/api/v1/users/lookup?phone={phone}", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(caller.accessToken())), Map.class, phone);
    }

    /** Phone sign-up via SMS code — what makes the number "verified" and triggers pending invitations. */
    private ResponseEntity<Map> signUpWithPhone(String phone) {
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        String code = capturedOtps.byPhone.get(phone);
        ResponseEntity<Map> verified = restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, code), Map.class);
        assertThat(verified.getStatusCode()).isEqualTo(HttpStatus.OK);
        return verified;
    }

    private List<Map> getList(String path) {
        ResponseEntity<Map[]> response = restTemplate.getForEntity(path, Map[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return List.of(response.getBody());
    }

    private static String uniqueKzPhone() {
        long suffix = Math.abs(UUID.randomUUID().getMostSignificantBits() % 10_000_000L);
        return String.format("+7700%07d", suffix);
    }
}
