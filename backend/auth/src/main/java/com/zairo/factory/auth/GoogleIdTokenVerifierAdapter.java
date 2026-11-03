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
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Real Google ID token verification against Google's own {@code tokeninfo}
 * endpoint — the server-side verification mechanism Google documents at
 * https://developers.google.com/identity/sign-in/web/backend-auth as an
 * alternative to their client library, and the one that fits this
 * codebase's existing convention of a plain {@code java.net.http.HttpClient}
 * call against a documented provider REST endpoint for one adapter (see
 * {@code payment-provider}'s {@code FreedomPayHttpClient} — same reasoning,
 * no new HTTP framework dependency for a single integration) rather than
 * pulling in Google's much heavier {@code google-api-client} tree.
 *
 * <p>What CLAUDE.md's task spec §3 asks for, and how this gets it — all
 * without any custom cryptography, exactly as required:
 *
 * <ul>
 *   <li><b>Signature</b> — verified entirely by Google's endpoint itself;
 *       an invalid signature makes the whole call fail with HTTP 400, never
 *       reaching this class's field checks below.
 *   <li><b>Expiration</b> — same: an expired token is rejected by Google
 *       with HTTP 400 before this class sees a body. The {@code exp} field
 *       is still re-checked defensively in case that ever changes.
 *   <li><b>Issuer</b> — {@code iss} must be {@code accounts.google.com} or
 *       {@code https://accounts.google.com}.
 *   <li><b>Audience</b> — {@code aud} must be one of
 *       {@code app.oauth.google.client-ids} (comma-separated: the Android
 *       client id, the iOS client id, and optionally a web client id — see
 *       docs/authentication.md's "Google configuration" section for where
 *       each comes from). Left blank, no audience is enforced — never true
 *       in production, see ProductionSecretsValidator.
 * </ul>
 *
 * <p>Every failure — network error, non-200, wrong issuer/audience,
 * malformed body — collapses to an empty {@link Optional}; see
 * GoogleIdTokenVerifierPort's doc comment for why callers must not try to
 * distinguish which one happened.
 */
@Component
class GoogleIdTokenVerifierAdapter implements GoogleIdTokenVerifierPort {

    private static final Logger log = LoggerFactory.getLogger(GoogleIdTokenVerifierAdapter.class);
    private static final Set<String> VALID_ISSUERS = Set.of("accounts.google.com", "https://accounts.google.com");
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

    private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    // Built directly rather than injected: Spring Boot 4.1's auto-configured
    // ObjectMapper bean is the new Jackson 3 (tools.jackson.databind) type,
    // not this classic Jackson 2 (com.fasterxml.jackson.databind) one — see
    // git history for the exact "no qualifying bean" startup failure this
    // caused. This class only does ad-hoc readTree() parsing of Google's
    // tokeninfo response, with no need for Spring's managed configuration.
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final List<String> audiences;
    private final String tokenInfoUrl;
    private final boolean enabled;

    GoogleIdTokenVerifierAdapter(@Value("${app.oauth.google.client-ids:}") String clientIdsCsv,
            @Value("${app.oauth.google.tokeninfo-url:https://oauth2.googleapis.com/tokeninfo}") String tokenInfoUrl,
            @Value("${app.oauth.google.enabled:true}") boolean enabled) {
        this.enabled = enabled;
        this.audiences = Arrays.stream(clientIdsCsv.split(",")).map(String::trim).filter(id -> !id.isEmpty()).toList();
        this.tokenInfoUrl = tokenInfoUrl;
    }

    @Override
    public Optional<VerifiedIdentity> verify(String idToken) {
        // Switched off (app.oauth.google.enabled=false): no token is ever accepted, and Google is not contacted.
        // Fails closed, so a blank client-id list can never fall back to "accept any audience".
        if (!enabled || idToken == null || idToken.isBlank()) {
            return Optional.empty();
        }
        try {
            URI uri = URI.create(tokenInfoUrl + "?id_token=" + URLEncoder.encode(idToken, StandardCharsets.UTF_8));
            HttpRequest request = HttpRequest.newBuilder(uri).timeout(REQUEST_TIMEOUT).GET().build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() != 200) {
                return Optional.empty();
            }

            JsonNode node = objectMapper.readTree(response.body());
            if (!VALID_ISSUERS.contains(node.path("iss").asText(""))) {
                return Optional.empty();
            }
            String audience = node.path("aud").asText("");
            if (!audiences.isEmpty() && !audiences.contains(audience)) {
                return Optional.empty();
            }
            long expiresAtEpochSeconds = node.path("exp").asLong(0);
            if (expiresAtEpochSeconds <= 0 || Instant.ofEpochSecond(expiresAtEpochSeconds).isBefore(Instant.now())) {
                return Optional.empty();
            }
            String subject = node.path("sub").asText("");
            if (subject.isBlank()) {
                return Optional.empty();
            }

            boolean emailVerified = "true".equalsIgnoreCase(node.path("email_verified").asText("false"));
            String email = node.hasNonNull("email") ? node.get("email").asText() : null;
            String name = node.hasNonNull("name") ? node.get("name").asText() : null;
            return Optional.of(new VerifiedIdentity(subject, email, emailVerified, name));
        } catch (IOException e) {
            log.warn("Google ID token verification failed: {}", e.getMessage());
            return Optional.empty();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return Optional.empty();
        }
    }
}
