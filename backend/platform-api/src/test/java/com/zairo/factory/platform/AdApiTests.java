package com.zairo.factory.platform;

import static org.assertj.core.api.Assertions.assertThat;

import com.zairo.factory.platformadmin.PlatformAdminAccountRepository;
import com.zairo.factory.platformadmin.PlatformRole;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
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
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Against a real Postgres (Testcontainers): the public Home carousel only
 * serves live banners for the caller's city, and the platform endpoints are
 * gated (support is read-only), validated and moved through the lifecycle.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@Import(TestcontainersConfiguration.class)
class AdApiTests {

    private static final String COVER = "https://cdn.example/cover.jpg";

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private PlatformAdminAccountRepository platformAdminAccountRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @AfterEach
    void clean() {
        jdbcTemplate.update("delete from ad_banner");
    }

    private TestPlatformAuth.Registered register(PlatformRole role) {
        return TestPlatformAuth.registerPlatformAdmin(restTemplate, platformAdminAccountRepository,
                "ads-" + role.name().toLowerCase() + "-" + UUID.randomUUID() + "@factory.internal", role);
    }

    private Map<String, Object> body(String title, String city, Instant start, Instant end, String status) {
        java.util.HashMap<String, Object> map = new java.util.HashMap<>();
        map.put("title", title);
        map.put("imageUrl", COVER);
        map.put("videoUrl", "https://video.example/watch?v=1");
        map.put("cityCode", city);
        map.put("startsAt", start.toString());
        map.put("endsAt", end.toString());
        map.put("status", status);
        return map;
    }

    private ResponseEntity<Map> post(String token, Map<String, Object> body) {
        return restTemplate.exchange("/api/v1/platform/ads", HttpMethod.POST,
                new HttpEntity<>(body, TestPlatformAuth.authHeaders(token)), Map.class);
    }

    private List<String> publicTitles(String query) {
        ResponseEntity<List> response = restTemplate.getForEntity("/api/v1/ads/banners" + query, List.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        return ((List<?>) response.getBody()).stream().map(e -> (String) ((Map<?, ?>) e).get("title")).toList();
    }

    @Test
    void thePublicCarouselOnlyShowsLiveBannersForTheCity() {
        var admin = register(PlatformRole.PLATFORM_ADMIN);
        Instant now = Instant.now();
        post(admin.accessToken(), body("everywhere", null, now.minus(1, ChronoUnit.HOURS),
                now.plus(1, ChronoUnit.HOURS), "ACTIVE"));
        post(admin.accessToken(), body("almaty-only", "almaty", now.minus(1, ChronoUnit.HOURS),
                now.plus(1, ChronoUnit.HOURS), "ACTIVE"));
        post(admin.accessToken(), body("draft", null, now.minus(1, ChronoUnit.HOURS),
                now.plus(1, ChronoUnit.HOURS), "DRAFT"));
        post(admin.accessToken(), body("expired", null, now.minus(2, ChronoUnit.HOURS),
                now.minus(1, ChronoUnit.HOURS), "ACTIVE"));
        post(admin.accessToken(), body("future", null, now.plus(1, ChronoUnit.HOURS),
                now.plus(2, ChronoUnit.HOURS), "ACTIVE"));

        // A guest, no city: only the every-city banner.
        assertThat(publicTitles("")).containsExactly("everywhere");
        // In Almaty: both live ones.
        assertThat(publicTitles("?city=almaty")).containsExactlyInAnyOrder("everywhere", "almaty-only");
        // In another city: the Almaty banner is not shown.
        assertThat(publicTitles("?city=astana")).containsExactly("everywhere");
    }

    @Test
    void platformEndpointsAreGatedAndSupportIsReadOnly() {
        var admin = register(PlatformRole.PLATFORM_ADMIN);
        var moderator = register(PlatformRole.PLATFORM_MODERATOR);
        var support = register(PlatformRole.PLATFORM_SUPPORT);
        Instant now = Instant.now();
        Map<String, Object> request = body("gated", null, now, now.plus(1, ChronoUnit.HOURS), null);

        assertThat(restTemplate.postForEntity("/api/v1/platform/ads", request, Map.class).getStatusCode())
                .isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(post(support.accessToken(), request).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(post(moderator.accessToken(), request).getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<List> asSupport = restTemplate.exchange("/api/v1/platform/ads", HttpMethod.GET,
                new HttpEntity<>(TestPlatformAuth.authHeaders(support.accessToken())), List.class);
        assertThat(asSupport.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(asSupport.getBody()).hasSize(1);
        assertThat(restTemplate.getForEntity("/api/v1/platform/ads", Map.class).getStatusCode())
                .isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(admin.accessToken()).isNotBlank();
    }

    @Test
    void invalidBannersAreRefused() {
        var admin = register(PlatformRole.PLATFORM_ADMIN);
        Instant now = Instant.now();

        Map<String, Object> http = body("t", null, now, now.plus(1, ChronoUnit.HOURS), null);
        http.put("imageUrl", "http://cdn.example/cover.jpg");
        assertThat(post(admin.accessToken(), http).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        assertThat(post(admin.accessToken(), body("t", null, now.plus(1, ChronoUnit.HOURS), now, null))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        assertThat(post(admin.accessToken(), body("t", null, now, now.plus(1, ChronoUnit.HOURS), "REJECTED"))
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        Map<String, Object> unknownCity = body("t", "no-such-city", now, now.plus(1, ChronoUnit.HOURS), null);
        assertThat(post(admin.accessToken(), unknownCity).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void aBannerGoesThroughReviewAndIsAuditLogged() {
        var admin = register(PlatformRole.PLATFORM_ADMIN);
        Instant now = Instant.now();
        ResponseEntity<Map> created = post(admin.accessToken(),
                body("lifecycle", null, now.minus(1, ChronoUnit.HOURS), now.plus(1, ChronoUnit.HOURS), null));
        String id = (String) created.getBody().get("id");
        assertThat(created.getBody().get("status")).isEqualTo("DRAFT");
        assertThat(publicTitles("")).isEmpty();

        // Approve it, then a rejection without a reason is refused and the banner stays live.
        assertThat(status(admin.accessToken(), id, Map.of("status", "ACTIVE")).getStatusCode())
                .isEqualTo(HttpStatus.OK);
        ResponseEntity<Map> rejectedNoReason = status(admin.accessToken(), id, Map.of("status", "REJECTED"));
        assertThat(rejectedNoReason.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(publicTitles("")).containsExactly("lifecycle");

        // Pause hides it; a forbidden move is a 409.
        assertThat(status(admin.accessToken(), id, Map.of("status", "PAUSED")).getStatusCode())
                .isEqualTo(HttpStatus.OK);
        assertThat(publicTitles("")).isEmpty();
        assertThat(status(admin.accessToken(), id, Map.of("status", "PENDING_REVIEW")).getStatusCode())
                .isEqualTo(HttpStatus.CONFLICT);

        Integer logged = jdbcTemplate.queryForObject(
                "select count(*) from platform_audit_log where target_type = 'AD_BANNER' and target_id = ?::uuid",
                Integer.class, id);
        assertThat(logged).isGreaterThanOrEqualTo(3);

        // Delete removes it for good.
        ResponseEntity<Void> deleted = restTemplate.exchange("/api/v1/platform/ads/" + id, HttpMethod.DELETE,
                new HttpEntity<>(TestPlatformAuth.authHeaders(admin.accessToken())), Void.class);
        assertThat(deleted.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(status(admin.accessToken(), id, Map.of("status", "ACTIVE")).getStatusCode())
                .isEqualTo(HttpStatus.NOT_FOUND);
    }

    private ResponseEntity<Map> status(String token, String id, Map<String, Object> body) {
        return restTemplate.exchange("/api/v1/platform/ads/" + id + "/status", HttpMethod.PATCH,
                new HttpEntity<>(body, TestPlatformAuth.authHeaders(token)), Map.class);
    }
}
