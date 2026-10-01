package com.zairo.factory.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Real Facebook access-token verification against the Graph API — see
 * CLAUDE.md task spec §4. Facebook has no JWKS/ID-token mechanism like
 * Google's; the standard, Facebook-documented way to verify a client-
 * supplied user access token belongs to both a real Facebook session *and*
 * this specific app is two calls, both plain {@code java.net.http.HttpClient}
 * requests — same convention as GoogleIdTokenVerifierAdapter/{@code
 * payment-provider}'s FreedomPayHttpClient, no new HTTP framework
 * dependency:
 *
 * <ol>
 *   <li>{@code GET /debug_token?input_token=<token>&access_token=<appId>|<appSecret>}
 *       — an app-token-authenticated call that returns whether the token is
 *       currently valid, which app it was issued to, and the Facebook user
 *       id it belongs to. This stands in for "signature + audience +
 *       expiration": forging a token that passes this call would require
 *       the app secret itself, which never leaves this server.
 *   <li>{@code GET /me?fields=id,email,name&access_token=<token>} — the
 *       actual profile lookup, using the token as-is (proves it's still
 *       live, not just previously valid). Its {@code id} is cross-checked
 *       against debug_token's {@code user_id} so a token that passed step 1
 *       for a different Facebook user can't be substituted here.
 * </ol>
 *
 * <p>{@code subject} is Graph's {@code id} — an app-scoped, stable Facebook
 * user id, never the client-supplied email/name (see
 * FacebookIdentityVerifierPort's doc comment on why those are untrusted
 * until this class returns them).
 */
@Component
class FacebookGraphIdentityVerifier implements FacebookIdentityVerifierPort {

    private static final Logger log = LoggerFactory.getLogger(FacebookGraphIdentityVerifier.class);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

    private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    // Built directly rather than injected — see GoogleIdTokenVerifierAdapter's
    // identical field for why: Spring Boot 4.1 only auto-configures a Jackson
    // 3 ObjectMapper bean, not this classic Jackson 2 one.
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final String appId;
    private final String appAccessToken;
    private final String graphApiBaseUrl;

    FacebookGraphIdentityVerifier(@Value("${app.oauth.facebook.app-id:}") String appId,
            @Value("${app.oauth.facebook.app-secret:}") String appSecret,
            @Value("${app.oauth.facebook.graph-api-base-url:https://graph.facebook.com}") String graphApiBaseUrl) {
        this.appId = appId;
        this.appAccessToken = appId + "|" + appSecret;
        this.graphApiBaseUrl = graphApiBaseUrl;
    }

    @Override
    public Optional<VerifiedIdentity> verify(String userAccessToken) {
        if (userAccessToken == null || userAccessToken.isBlank() || appId.isBlank()) {
            return Optional.empty();
        }
        try {
            JsonNode debug = get("/debug_token", "input_token", userAccessToken, "access_token", appAccessToken);
            JsonNode data = debug == null ? null : debug.path("data");
            if (data == null || !data.path("is_valid").asBoolean(false) || !appId.equals(data.path("app_id").asText(""))) {
                return Optional.empty();
            }
            String userId = data.path("user_id").asText("");
            if (userId.isBlank()) {
                return Optional.empty();
            }

            JsonNode me = get("/me", "fields", "id,email,name", "access_token", userAccessToken);
            if (me == null || !userId.equals(me.path("id").asText(""))) {
                return Optional.empty();
            }

            String email = me.hasNonNull("email") ? me.get("email").asText() : null;
            String name = me.hasNonNull("name") ? me.get("name").asText() : null;
            return Optional.of(new VerifiedIdentity(userId, email, email != null, name));
        } catch (IOException e) {
            log.warn("Facebook access token verification failed: {}", e.getMessage());
            return Optional.empty();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return Optional.empty();
        }
    }

    private JsonNode get(String path, String... queryKeysAndValues) throws IOException, InterruptedException {
        StringBuilder query = new StringBuilder();
        for (int i = 0; i < queryKeysAndValues.length; i += 2) {
            query.append(i == 0 ? "" : "&").append(queryKeysAndValues[i]).append('=')
                    .append(URLEncoder.encode(queryKeysAndValues[i + 1], StandardCharsets.UTF_8));
        }
        URI uri = URI.create(graphApiBaseUrl + path + "?" + query);
        HttpRequest request = HttpRequest.newBuilder(uri).timeout(REQUEST_TIMEOUT).GET().build();
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        if (response.statusCode() != 200) {
            return null;
        }
        return objectMapper.readTree(response.body());
    }
}
