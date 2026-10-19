package com.zairo.factory.platform.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class AuthRateLimitFilterTests {

    private final AtomicReference<Instant> now = new AtomicReference<>(Instant.parse("2026-10-18T10:00:00Z"));
    private final Clock clock = new Clock() {
        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now.get();
        }
    };

    private AuthRateLimitFilter filter(boolean enabled) {
        return new AuthRateLimitFilter(enabled, 1, clock);
    }

    private MockHttpServletResponse post(AuthRateLimitFilter filter, String path, String ip, String body)
            throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", path);
        request.addHeader("X-Forwarded-For", ip);
        request.setContentType("application/json");
        request.setContent(body.getBytes(StandardCharsets.UTF_8));
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, new MockFilterChain());
        return response;
    }

    @Test
    void aCallerOverTheIpLimitGets429WithRetryAfterAndAnApiErrorBody() throws Exception {
        AuthRateLimitFilter filter = filter(true);
        for (int i = 0; i < 30; i++) {
            assertThat(post(filter, "/api/v1/auth/login", "1.1.1.1", "{}").getStatus()).isEqualTo(200);
        }

        MockHttpServletResponse limited = post(filter, "/api/v1/auth/login", "1.1.1.1", "{}");

        assertThat(limited.getStatus()).isEqualTo(429);
        assertThat(Long.parseLong(limited.getHeader("Retry-After"))).isBetween(1L, 60L);
        assertThat(limited.getContentAsString()).contains("\"status\":429").contains("\"error\":\"Too Many Requests\"");
        // Another address is not affected.
        assertThat(post(filter, "/api/v1/auth/login", "2.2.2.2", "{}").getStatus()).isEqualTo(200);
    }

    @Test
    void theWindowResetsAfterItPasses() throws Exception {
        AuthRateLimitFilter filter = filter(true);
        for (int i = 0; i < 31; i++) {
            post(filter, "/api/v1/auth/login", "1.1.1.1", "{}");
        }
        assertThat(post(filter, "/api/v1/auth/login", "1.1.1.1", "{}").getStatus()).isEqualTo(429);

        now.set(now.get().plus(Duration.ofSeconds(61)));

        assertThat(post(filter, "/api/v1/auth/login", "1.1.1.1", "{}").getStatus()).isEqualTo(200);
    }

    @Test
    void forgotPasswordIsAlsoLimitedPerEmailSoAVictimIsNotMailBombedFromManyAddresses() throws Exception {
        AuthRateLimitFilter filter = filter(true);
        String body = "{\"email\":\"Victim@Example.com\"}";
        for (int i = 0; i < 3; i++) {
            assertThat(post(filter, "/api/v1/auth/forgot-password", "10.0.0." + i, body).getStatus()).isEqualTo(200);
        }

        MockHttpServletResponse limited = post(filter, "/api/v1/auth/forgot-password", "10.0.0.99",
                "{\"email\":\"victim@example.com\"}");

        assertThat(limited.getStatus()).isEqualTo(429);
        assertThat(post(filter, "/api/v1/auth/forgot-password", "10.0.0.99", "{\"email\":\"other@example.com\"}")
                .getStatus()).isEqualTo(200);
    }

    @Test
    void thePlatformConsoleLoginIsLimitedHardAndTheBodyStillReachesTheController() throws Exception {
        AuthRateLimitFilter filter = filter(true);
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/platform/auth/login");
        request.addHeader("X-Forwarded-For", "3.3.3.3");
        request.setContent("{\"email\":\"admin@example.com\",\"password\":\"x\"}".getBytes(StandardCharsets.UTF_8));
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        String replayed = new String(chain.getRequest().getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        assertThat(replayed).isEqualTo("{\"email\":\"admin@example.com\",\"password\":\"x\"}");
        for (int i = 0; i < 9; i++) {
            assertThat(post(filter, "/api/v1/platform/auth/login", "3.3.3.3", "{\"email\":\"a" + i + "@x.com\"}")
                    .getStatus()).isEqualTo(200);
        }
        assertThat(post(filter, "/api/v1/platform/auth/login", "3.3.3.3", "{}").getStatus()).isEqualTo(429);
    }

    @Test
    void otherPathsAndMethodsAreNotCounted() throws Exception {
        AuthRateLimitFilter filter = filter(true);
        for (int i = 0; i < 100; i++) {
            assertThat(post(filter, "/api/v1/bookings", "1.1.1.1", "{}").getStatus()).isEqualTo(200);
            MockHttpServletResponse get = new MockHttpServletResponse();
            filter.doFilter(new MockHttpServletRequest("GET", "/api/v1/auth/login"), get, new MockFilterChain());
            assertThat(get.getStatus()).isEqualTo(200);
        }
    }

    @Test
    void whenDisabledNothingIsLimited() throws Exception {
        AuthRateLimitFilter filter = filter(false);
        for (int i = 0; i < 100; i++) {
            assertThat(post(filter, "/api/v1/auth/login", "1.1.1.1", "{}").getStatus()).isEqualTo(200);
        }
    }

    @Test
    void anOversizedSignInBodyIsRefusedInsteadOfBeingHalfRead() throws Exception {
        AuthRateLimitFilter filter = filter(true);

        MockHttpServletResponse response = post(filter, "/api/v1/auth/register", "1.1.1.1", "x".repeat(9 * 1024));

        assertThat(response.getStatus()).isEqualTo(413);
    }

    @Test
    void aBodyThatIsNotJsonIsLeftForTheControllerToReject() throws Exception {
        AuthRateLimitFilter filter = filter(true);

        assertThat(post(filter, "/api/v1/auth/register", "1.1.1.1", "not json").getStatus()).isEqualTo(200);
    }

    @Test
    void expiredWindowsAreSweptSoTheMapCannotGrowForever() {
        FixedWindowCounter counter = new FixedWindowCounter(clock);
        for (int i = 0; i < FixedWindowCounter.SWEEP_THRESHOLD + 5; i++) {
            counter.hit("k" + i, 5, 60);
        }
        now.set(now.get().plus(Duration.ofSeconds(120)));

        counter.hit("fresh", 5, 60);

        assertThat(counter.trackedKeys()).isEqualTo(1);
    }
}
