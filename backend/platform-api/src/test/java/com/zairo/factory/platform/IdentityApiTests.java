package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.auth.AuthDtos.FacebookAuthRequest;
import com.zairo.factory.auth.AuthDtos.GoogleAuthRequest;
import com.zairo.factory.auth.AuthDtos.RegisterRequest;
import com.zairo.factory.auth.AuthDtos.RequestPhoneOtpRequest;
import com.zairo.factory.auth.AuthDtos.UpdateProfileRequest;
import com.zairo.factory.auth.AuthDtos.VerifyPhoneOtpRequest;
import com.zairo.factory.users.UserRole;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
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
 * Google / Facebook / phone-OTP sign-in and account linking, against a real
 * Postgres (Testcontainers) — same style as AuthApiTests. Provider
 * verification itself is faked (see TestIdentityProviders): what's under
 * test here is IdentityService/IdentityController's own logic — the single
 * identity model, account linking, duplicate-identity protection, and the
 * "don't silently merge on matching email" rule (CLAUDE.md task spec §8) —
 * not Google's or Facebook's cryptography, which this codebase doesn't
 * reimplement (see GoogleIdTokenVerifierAdapter/FacebookGraphIdentityVerifier).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        // Overrides the real 60s resend cooldown (see application.yml's
        // app.otp block) to 0 so back-to-back request-otp calls in the same
        // test (e.g. verifyingTheSamePhoneTwiceLogsIntoTheSameAccount) stay
        // deterministic without sleeping. PhoneOtpServiceTest is what
        // actually exercises the real cooldown value.
        properties = "app.otp.resend-cooldown-seconds=0")
@AutoConfigureTestRestTemplate
@Import({TestcontainersConfiguration.class, TestNotifications.class, TestIdentityProviders.class})
class IdentityApiTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private TestIdentityProviders.CapturedOtps capturedOtps;

    // ---- Google ---------------------------------------------------------

    @Test
    void googleSignInCreatesANewAccountOnFirstLogin() {
        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), null, false, "Aigerim");

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/google",
                new GoogleAuthRequest(token), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("accessToken")).isNotNull();
        Map<?, ?> user = (Map<?, ?>) response.getBody().get("user");
        assertThat(user.get("displayName")).isEqualTo("Aigerim");
        assertThat(user.get("email")).isNull();
    }

    @Test
    void googleSignInWithTheSameIdentityTwiceLogsIntoTheSameAccount() {
        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), null, false, "Askar");

        Map<?, ?> first = restTemplate.postForEntity("/api/v1/auth/google", new GoogleAuthRequest(token), Map.class)
                .getBody();
        Map<?, ?> second = restTemplate.postForEntity("/api/v1/auth/google", new GoogleAuthRequest(token), Map.class)
                .getBody();

        assertThat(userId(second)).isEqualTo(userId(first));
    }

    @Test
    void googleSignInRejectsAnInvalidCredential() {
        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/google",
                new GoogleAuthRequest(TestIdentityProviders.INVALID_GOOGLE_TOKEN), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void googleSignInWithAVerifiedEmailAlreadyRegisteredIsRejectedRatherThanMerged() {
        String email = "already-" + UUID.randomUUID() + "@example.com";
        restTemplate.postForEntity("/api/v1/auth/register",
                new RegisterRequest(email, "password123", "Existing User", "+1900000001", UserRole.CUSTOMER),
                Map.class);

        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), email, true, "Someone");
        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/google",
                new GoogleAuthRequest(token), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void googleSignInIgnoresAnUnverifiedEmailEvenIfItMatchesAnExistingAccount() {
        // An unverified email claim from the provider must never be trusted
        // enough to either merge accounts or block a new signup — see
        // GoogleIdTokenVerifierPort's emailVerified field and
        // IdentityService.findOrCreateUser, which only looks up an existing
        // account by email when emailVerified is true.
        String email = "unverified-" + UUID.randomUUID() + "@example.com";
        restTemplate.postForEntity("/api/v1/auth/register",
                new RegisterRequest(email, "password123", "Existing User", "+1900000002", UserRole.CUSTOMER),
                Map.class);

        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), email, false, "Someone");
        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/google",
                new GoogleAuthRequest(token), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((Map<?, ?>) response.getBody().get("user")).get("email")).isNull();
    }

    @Test
    void linkingGoogleToTheCurrentUserThenListsIt() {
        TestAuth.Registered owner = TestAuth.registerCustomer(restTemplate, "link-google-" + UUID.randomUUID()
                + "@example.com");
        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), null, false, null);

        ResponseEntity<Map> linkResponse = restTemplate.exchange("/api/v1/auth/identities/google", HttpMethod.POST,
                new HttpEntity<>(new GoogleAuthRequest(token), TestAuth.authHeaders(owner.accessToken())), Map.class);
        assertThat(linkResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map> identities = restTemplate.exchange("/api/v1/auth/identities", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        List<?> list = (List<?>) identities.getBody().get("identities");
        assertThat(list).hasSize(1);
        assertThat(((Map<?, ?>) list.get(0)).get("provider")).isEqualTo("GOOGLE");
    }

    @Test
    void linkingGoogleAlreadyLinkedToSomeoneElseIsRejected() {
        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), null, false, null);
        restTemplate.postForEntity("/api/v1/auth/google", new GoogleAuthRequest(token), Map.class); // owns it now

        TestAuth.Registered second = TestAuth.registerCustomer(restTemplate, "second-owner-" + UUID.randomUUID()
                + "@example.com");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auth/identities/google", HttpMethod.POST,
                new HttpEntity<>(new GoogleAuthRequest(token), TestAuth.authHeaders(second.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void linkingGoogleAlreadyLinkedToTheCallerThemselvesIsIdempotent() {
        TestAuth.Registered owner = TestAuth.registerCustomer(restTemplate, "idempotent-" + UUID.randomUUID()
                + "@example.com");
        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), null, false, null);
        HttpEntity<GoogleAuthRequest> request = new HttpEntity<>(new GoogleAuthRequest(token),
                TestAuth.authHeaders(owner.accessToken()));

        ResponseEntity<Map> first = restTemplate.exchange("/api/v1/auth/identities/google", HttpMethod.POST, request,
                Map.class);
        ResponseEntity<Map> second = restTemplate.exchange("/api/v1/auth/identities/google", HttpMethod.POST,
                request, Map.class);

        assertThat(first.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(second.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    /** Two concurrent first-time logins for the *same* new Google identity must land on exactly one account. */
    @Test
    void concurrentFirstTimeGoogleSignInsForTheSameIdentityCreateOnlyOneAccount() throws InterruptedException {
        String token = TestIdentityProviders.googleToken("google-sub-" + UUID.randomUUID(), null, false, "Racer");
        int threads = 6;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch go = new CountDownLatch(1);
        List<AtomicReference<String>> results = new java.util.ArrayList<>();
        for (int i = 0; i < threads; i++) {
            results.add(new AtomicReference<>());
        }

        try {
            for (int i = 0; i < threads; i++) {
                int index = i;
                pool.submit(() -> {
                    ready.countDown();
                    try {
                        go.await(10, TimeUnit.SECONDS);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                    ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/google",
                            new GoogleAuthRequest(token), Map.class);
                    if (response.getStatusCode() == HttpStatus.OK) {
                        results.get(index).set(userId(response.getBody()));
                    }
                });
            }
            ready.await(10, TimeUnit.SECONDS);
            go.countDown();
        } finally {
            pool.shutdown();
            pool.awaitTermination(30, TimeUnit.SECONDS);
        }

        List<String> userIds = results.stream().map(AtomicReference::get).filter(java.util.Objects::nonNull)
                .distinct().toList();
        assertThat(userIds).as("every successful concurrent sign-in for the same identity resolves to one account")
                .hasSize(1);
    }

    // ---- Facebook ---------------------------------------------------------

    @Test
    void facebookSignInCreatesANewAccountOnFirstLogin() {
        String token = TestIdentityProviders.facebookToken("fb-sub-" + UUID.randomUUID(), null, "Nurlan");

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/facebook",
                new FacebookAuthRequest(token), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((Map<?, ?>) response.getBody().get("user")).get("displayName")).isEqualTo("Nurlan");
    }

    @Test
    void facebookSignInWithTheSameIdentityTwiceLogsIntoTheSameAccount() {
        String token = TestIdentityProviders.facebookToken("fb-sub-" + UUID.randomUUID(), null, "Dana");

        Map<?, ?> first = restTemplate.postForEntity("/api/v1/auth/facebook", new FacebookAuthRequest(token),
                Map.class).getBody();
        Map<?, ?> second = restTemplate.postForEntity("/api/v1/auth/facebook", new FacebookAuthRequest(token),
                Map.class).getBody();

        assertThat(userId(second)).isEqualTo(userId(first));
    }

    @Test
    void facebookSignInRejectsAnInvalidCredential() {
        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/facebook",
                new FacebookAuthRequest(TestIdentityProviders.INVALID_FACEBOOK_TOKEN), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void linkingFacebookAlreadyLinkedToSomeoneElseIsRejected() {
        String token = TestIdentityProviders.facebookToken("fb-sub-" + UUID.randomUUID(), null, null);
        restTemplate.postForEntity("/api/v1/auth/facebook", new FacebookAuthRequest(token), Map.class);

        TestAuth.Registered second = TestAuth.registerCustomer(restTemplate, "fb-second-" + UUID.randomUUID()
                + "@example.com");
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auth/identities/facebook", HttpMethod.POST,
                new HttpEntity<>(new FacebookAuthRequest(token), TestAuth.authHeaders(second.accessToken())),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    // ---- Phone + OTP ---------------------------------------------------------

    @Test
    void requestingAnOtpThenVerifyingItCreatesAndLogsIntoANewAccount() {
        String phone = uniqueKzPhone();

        ResponseEntity<Void> requested = restTemplate.postForEntity("/api/v1/auth/phone/request-otp",
                new RequestPhoneOtpRequest(phone), Void.class);
        assertThat(requested.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        String code = capturedOtps.byPhone.get(phone);
        assertThat(code).matches("\\d{6}");

        ResponseEntity<Map> verified = restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, code), Map.class);
        assertThat(verified.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(verified.getBody().get("accessToken")).isNotNull();
    }

    @Test
    void verifyingTheSamePhoneTwiceLogsIntoTheSameAccount() {
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        String firstCode = capturedOtps.byPhone.get(phone);
        Map<?, ?> first = restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, firstCode), Map.class).getBody();

        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        // Would be rejected by the resend cooldown under the real 60s
        // default — see this class's @SpringBootTest properties override.
        String secondCode = capturedOtps.byPhone.get(phone);
        Map<?, ?> second = restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, secondCode), Map.class).getBody();

        assertThat(userId(second)).isEqualTo(userId(first));
    }

    @Test
    void verifyingWithTheWrongCodeIsRejected() {
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);

        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, "000000"), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void aConsumedOtpCannotBeReplayed() {
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        String code = capturedOtps.byPhone.get(phone);
        restTemplate.postForEntity("/api/v1/auth/phone/verify-otp", new VerifyPhoneOtpRequest(phone, code),
                Map.class);

        ResponseEntity<Map> replay = restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, code), Map.class);

        assertThat(replay.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void invalidPhoneNumberIsRejectedBeforeAnOtpIsEverSent() {
        ResponseEntity<Map> response = restTemplate.postForEntity("/api/v1/auth/phone/request-otp",
                new RequestPhoneOtpRequest("not-a-phone-number"), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void linkingAVerifiedPhoneToTheCurrentUserThenListsIt() {
        TestAuth.Registered owner = TestAuth.registerCustomer(restTemplate, "link-phone-" + UUID.randomUUID()
                + "@example.com");
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        String code = capturedOtps.byPhone.get(phone);

        ResponseEntity<Map> linkResponse = restTemplate.exchange("/api/v1/auth/identities/phone/verify-otp",
                HttpMethod.POST, new HttpEntity<>(new VerifyPhoneOtpRequest(phone, code),
                        TestAuth.authHeaders(owner.accessToken())), Map.class);

        assertThat(linkResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map> identities = restTemplate.exchange("/api/v1/auth/identities", HttpMethod.GET,
                new HttpEntity<>(null, TestAuth.authHeaders(owner.accessToken())), Map.class);
        List<Map<?, ?>> list = (List<Map<?, ?>>) (List<?>) identities.getBody().get("identities");
        List<Object> providers = new java.util.ArrayList<>();
        for (Map<?, ?> item : list) {
            providers.add(item.get("provider"));
        }
        assertThat(providers).contains("PHONE");
    }

    @Test
    void linkingAPhoneAlreadyLinkedToSomeoneElseIsRejected() {
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, capturedOtps.byPhone.get(phone)), Map.class); // owns it now

        TestAuth.Registered second = TestAuth.registerCustomer(restTemplate, "phone-second-" + UUID.randomUUID()
                + "@example.com");
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auth/identities/phone/verify-otp",
                HttpMethod.POST, new HttpEntity<>(new VerifyPhoneOtpRequest(phone, capturedOtps.byPhone.get(phone)),
                        TestAuth.authHeaders(second.accessToken())), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    // ---- Profile completion ---------------------------------------------------------

    @Test
    void aPhoneOnlyAccountCanCompleteItsProfileWithADisplayNameAndEmail() {
        String phone = uniqueKzPhone();
        restTemplate.postForEntity("/api/v1/auth/phone/request-otp", new RequestPhoneOtpRequest(phone), Void.class);
        Map<?, ?> tokens = restTemplate.postForEntity("/api/v1/auth/phone/verify-otp",
                new VerifyPhoneOtpRequest(phone, capturedOtps.byPhone.get(phone)), Map.class).getBody();
        String accessToken = tokens.get("accessToken").toString();
        String email = "completed-" + UUID.randomUUID() + "@example.com";

        ResponseEntity<Map> response = restTemplate.exchange("/api/v1/auth/me", HttpMethod.PATCH,
                new HttpEntity<>(new UpdateProfileRequest("Real Name", email), TestAuth.authHeaders(accessToken)),
                Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("displayName")).isEqualTo("Real Name");
        assertThat(response.getBody().get("email")).isEqualTo(email);
    }

    private static String userId(Map<?, ?> tokenResponseBody) {
        return ((Map<?, ?>) tokenResponseBody.get("user")).get("id").toString();
    }

    /** "700" is a real Kazakhstani mobile operator prefix; the other 7 digits are randomized for test isolation. */
    private static String uniqueKzPhone() {
        long suffix = Math.abs(UUID.randomUUID().getMostSignificantBits() % 10_000_000L);
        return String.format("+7700%07d", suffix);
    }
}
