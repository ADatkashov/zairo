package com.zairo.factory.auth;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.yubico.webauthn.AssertionRequest;
import com.yubico.webauthn.AssertionResult;
import com.yubico.webauthn.CredentialRepository;
import com.yubico.webauthn.FinishAssertionOptions;
import com.yubico.webauthn.FinishRegistrationOptions;
import com.yubico.webauthn.RegisteredCredential;
import com.yubico.webauthn.RegistrationResult;
import com.yubico.webauthn.RelyingParty;
import com.yubico.webauthn.StartAssertionOptions;
import com.yubico.webauthn.StartRegistrationOptions;
import com.yubico.webauthn.data.AuthenticatorAssertionResponse;
import com.yubico.webauthn.data.AuthenticatorAttestationResponse;
import com.yubico.webauthn.data.AuthenticatorSelectionCriteria;
import com.yubico.webauthn.data.ByteArray;
import com.yubico.webauthn.data.ClientAssertionExtensionOutputs;
import com.yubico.webauthn.data.ClientRegistrationExtensionOutputs;
import com.yubico.webauthn.data.PublicKeyCredential;
import com.yubico.webauthn.data.PublicKeyCredentialCreationOptions;
import com.yubico.webauthn.data.PublicKeyCredentialDescriptor;
import com.yubico.webauthn.data.RelyingPartyIdentity;
import com.yubico.webauthn.data.ResidentKeyRequirement;
import com.yubico.webauthn.data.UserIdentity;
import com.yubico.webauthn.data.UserVerificationRequirement;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.nio.ByteBuffer;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Passkeys (WebAuthn) sign-in. All protocol and cryptographic verification —
 * challenge, origin, RP-id hash, signature, signature counter — is done by
 * Yubico's {@code webauthn-server-core}; this class owns what that library
 * deliberately leaves to the application: where credentials and in-flight
 * challenges are stored, which users they belong to, and issuing the session.
 *
 * <p>Design choices:
 * <ul>
 *   <li><b>Discoverable credentials</b> ("resident keys") are required, so
 *       sign-in needs no username: the device offers the person's passkeys
 *       and the user handle in the signed response says who it is.
 *   <li>The WebAuthn <b>user handle</b> is the user's UUID bytes — stable,
 *       opaque and carrying no personal data.
 *   <li>The RP id is permanent: changing {@code app.passkey.rp-id} later
 *       orphans every registered passkey.
 *   <li>Allowed origins: {@code https://<rp-id>} (iOS) plus an
 *       {@code android:apk-key-hash:...} origin derived from each configured
 *       app-signing SHA-256 fingerprint, plus any explicit extras.
 * </ul>
 */
@Component
class PasskeyService {

    private static final Duration CEREMONY_TTL = Duration.ofMinutes(5);
    private static final String DEFAULT_NAME_PREFIX = "Passkey ";

    private final PasskeyCredentialRepository credentials;
    private final WebauthnCeremonyRepository ceremonies;
    private final UserRepository userRepository;
    private final SessionIssuer sessionIssuer;
    private final AuthAuditLog auditLog;
    private final Clock clock;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final RelyingParty relyingParty; // null when passkeys are not configured

    @Autowired
    PasskeyService(PasskeyCredentialRepository credentials, WebauthnCeremonyRepository ceremonies,
            UserRepository userRepository, SessionIssuer sessionIssuer, AuthAuditLog auditLog,
            @Value("${app.passkey.rp-id:}") String rpId, @Value("${app.passkey.rp-name:ZAIRO}") String rpName,
            @Value("${app.passkey.android-sha256-fingerprints:}") String androidFingerprints,
            @Value("${app.passkey.extra-origins:}") String extraOrigins) {
        this(credentials, ceremonies, userRepository, sessionIssuer, auditLog, Clock.systemUTC(), rpId, rpName,
                androidFingerprints, extraOrigins);
    }

    /** Test seam — a controllable clock. */
    PasskeyService(PasskeyCredentialRepository credentials, WebauthnCeremonyRepository ceremonies,
            UserRepository userRepository, SessionIssuer sessionIssuer, AuthAuditLog auditLog, Clock clock,
            String rpId, String rpName, String androidFingerprints, String extraOrigins) {
        this.credentials = credentials;
        this.ceremonies = ceremonies;
        this.userRepository = userRepository;
        this.sessionIssuer = sessionIssuer;
        this.auditLog = auditLog;
        this.clock = clock;
        this.relyingParty = rpId == null || rpId.isBlank() ? null
                : RelyingParty.builder()
                        .identity(RelyingPartyIdentity.builder().id(rpId.trim()).name(rpName).build())
                        .credentialRepository(new Repo())
                        .origins(allowedOrigins(rpId.trim(), androidFingerprints, extraOrigins))
                        .build();
    }

    boolean isEnabled() {
        return relyingParty != null;
    }

    /** {@code https://<rp-id>}, plus an android:apk-key-hash origin per signing-cert fingerprint, plus extras. */
    static Set<String> allowedOrigins(String rpId, String androidFingerprints, String extraOrigins) {
        Set<String> origins = new LinkedHashSet<>();
        origins.add("https://" + rpId);
        for (String fingerprint : split(androidFingerprints)) {
            byte[] sha256 = HexFormat.of().parseHex(fingerprint.replace(":", "").toLowerCase());
            origins.add("android:apk-key-hash:" + Base64.getUrlEncoder().withoutPadding().encodeToString(sha256));
        }
        origins.addAll(split(extraOrigins));
        return origins;
    }

    private static List<String> split(String csv) {
        return csv == null ? List.of()
                : Arrays.stream(csv.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList();
    }

    // ---- Registration (the caller is already signed in) -------------------------

    record Started(UUID ceremonyId, Map<String, Object> options) {
    }

    @Transactional
    Started startRegistration(UUID userId) {
        requireEnabled();
        ceremonies.deleteExpired(Instant.now(clock));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User no longer exists"));
        String label = firstNonBlank(user.getEmail(), user.getPhone(), user.getDisplayName());
        UserIdentity identity = UserIdentity.builder().name(label).displayName(user.getDisplayName())
                .id(handleOf(userId)).build();
        PublicKeyCredentialCreationOptions options = relyingParty.startRegistration(StartRegistrationOptions.builder()
                .user(identity)
                .authenticatorSelection(AuthenticatorSelectionCriteria.builder()
                        .residentKey(ResidentKeyRequirement.REQUIRED)
                        .userVerification(UserVerificationRequirement.PREFERRED).build())
                .build());

        Map<String, Object> publicKey = publicKeyOf(toJson(options::toCredentialsCreateJson));
        // Don't offer to re-register a passkey this account already has on the device.
        List<Map<String, Object>> exclude = new ArrayList<>();
        for (PasskeyCredential existing : credentials.findByUserIdOrderByCreatedAtAsc(userId)) {
            exclude.add(Map.of("type", "public-key", "id",
                    new ByteArray(existing.getCredentialId()).getBase64Url()));
        }
        publicKey.put("excludeCredentials", exclude);

        UUID ceremonyId = save(WebauthnCeremony.Kind.REGISTER, userId, toJson(options::toJson));
        return new Started(ceremonyId, publicKey);
    }

    @Transactional
    PasskeyView finishRegistration(UUID userId, UUID ceremonyId, Map<String, Object> credentialJson, String name) {
        requireEnabled();
        WebauthnCeremony ceremony = consume(ceremonyId, WebauthnCeremony.Kind.REGISTER);
        if (!userId.equals(ceremony.getUserId())) {
            throw new InvalidProviderCredentialException("Invalid passkey registration");
        }
        RegistrationResult result;
        try {
            PublicKeyCredentialCreationOptions request = PublicKeyCredentialCreationOptions
                    .fromJson(ceremony.getRequestJson());
            PublicKeyCredential<AuthenticatorAttestationResponse, ClientRegistrationExtensionOutputs> response =
                    PublicKeyCredential.parseRegistrationResponseJson(objectMapper.writeValueAsString(credentialJson));
            result = relyingParty.finishRegistration(
                    FinishRegistrationOptions.builder().request(request).response(response).build());
        } catch (Exception e) {
            auditLog.loginFailed("PASSKEY_REGISTER", "invalid_credential");
            throw new InvalidProviderCredentialException("Invalid passkey registration");
        }
        String finalName = name == null || name.isBlank() ? DEFAULT_NAME_PREFIX + LocalDate.now(clock.withZone(ZoneOffset.UTC))
                : name.trim();
        try {
            PasskeyCredential saved = credentials.save(new PasskeyCredential(UUID.randomUUID(), userId,
                    result.getKeyId().getId().getBytes(), result.getPublicKeyCose().getBytes(),
                    result.getSignatureCount(), finalName.length() > 100 ? finalName.substring(0, 100) : finalName,
                    Instant.now(clock)));
            auditLog.passkeyRegistered(userId);
            return PasskeyView.of(saved);
        } catch (DataIntegrityViolationException e) {
            throw new IdentityAlreadyLinkedException("This passkey is already registered");
        }
    }

    // ---- Login (anonymous: discoverable credential) -----------------------------

    @Transactional
    Started startLogin() {
        requireEnabled();
        ceremonies.deleteExpired(Instant.now(clock));
        AssertionRequest request = relyingParty.startAssertion(StartAssertionOptions.builder()
                .userVerification(UserVerificationRequirement.PREFERRED).build());
        Map<String, Object> publicKey = publicKeyOf(toJson(request::toCredentialsGetJson));
        UUID ceremonyId = save(WebauthnCeremony.Kind.LOGIN, null, toJson(request::toJson));
        return new Started(ceremonyId, publicKey);
    }

    @Transactional
    TokenResponse finishLogin(UUID ceremonyId, Map<String, Object> credentialJson) {
        requireEnabled();
        WebauthnCeremony ceremony = consume(ceremonyId, WebauthnCeremony.Kind.LOGIN);
        User user;
        try {
            AssertionRequest request = AssertionRequest.fromJson(ceremony.getRequestJson());
            PublicKeyCredential<AuthenticatorAssertionResponse, ClientAssertionExtensionOutputs> response =
                    PublicKeyCredential.parseAssertionResponseJson(objectMapper.writeValueAsString(credentialJson));
            AssertionResult result = relyingParty
                    .finishAssertion(FinishAssertionOptions.builder().request(request).response(response).build());
            if (!result.isSuccess()) {
                throw new IllegalStateException("assertion not successful");
            }
            UUID userId = uuidOf(result.getUserHandle());
            PasskeyCredential credential = credentials.findByCredentialId(result.getCredentialId().getBytes())
                    .filter(c -> c.getUserId().equals(userId))
                    .orElseThrow(() -> new IllegalStateException("unknown credential"));
            credential.recordUse(result.getSignatureCount(), Instant.now(clock));
            credentials.save(credential);
            user = userRepository.findById(userId).orElseThrow(() -> new IllegalStateException("unknown user"));
        } catch (Exception e) {
            auditLog.loginFailed("PASSKEY", "invalid_credential");
            throw new InvalidProviderCredentialException("Invalid passkey credential");
        }
        auditLog.loginSucceeded(user.getId(), "PASSKEY");
        return sessionIssuer.issue(user);
    }

    // ---- Management -------------------------------------------------------------

    record PasskeyView(UUID id, String name, Instant createdAt, Instant lastUsedAt) {
        static PasskeyView of(PasskeyCredential c) {
            return new PasskeyView(c.getId(), c.getName(), c.getCreatedAt(), c.getLastUsedAt());
        }
    }

    @Transactional(readOnly = true)
    List<PasskeyView> list(UUID userId) {
        return credentials.findByUserIdOrderByCreatedAtAsc(userId).stream().map(PasskeyView::of).toList();
    }

    @Transactional
    void delete(UUID userId, UUID passkeyId) {
        PasskeyCredential credential = credentials.findById(passkeyId).filter(c -> c.getUserId().equals(userId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Passkey not found"));
        credentials.delete(credential);
        auditLog.passkeyRemoved(userId);
    }

    // ---- Helpers ----------------------------------------------------------------

    private void requireEnabled() {
        if (relyingParty == null) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Passkeys are not configured");
        }
    }

    private UUID save(WebauthnCeremony.Kind kind, UUID userId, String requestJson) {
        Instant now = Instant.now(clock);
        UUID id = UUID.randomUUID();
        ceremonies.save(new WebauthnCeremony(id, kind, userId, requestJson, now.plus(CEREMONY_TTL), now));
        return id;
    }

    /** Single-use: deleted as it is read, so a replayed finish call fails. */
    private WebauthnCeremony consume(UUID ceremonyId, WebauthnCeremony.Kind expectedKind) {
        WebauthnCeremony ceremony = ceremonies.findById(ceremonyId)
                .orElseThrow(() -> new InvalidProviderCredentialException("Invalid or expired passkey request"));
        if (ceremonies.consume(ceremonyId) == 0 || ceremony.getKind() != expectedKind
                || ceremony.isExpired(Instant.now(clock))) {
            throw new InvalidProviderCredentialException("Invalid or expired passkey request");
        }
        return ceremony;
    }

    private Map<String, Object> publicKeyOf(String credentialsJson) {
        try {
            Map<String, Object> wrapper = objectMapper.readValue(credentialsJson, new TypeReference<>() {
            });
            @SuppressWarnings("unchecked")
            Map<String, Object> publicKey = (Map<String, Object>) wrapper.get("publicKey");
            return publicKey;
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }

    @FunctionalInterface
    private interface JsonSupplier {
        String get() throws JsonProcessingException;
    }

    private static String toJson(JsonSupplier supplier) {
        try {
            return supplier.get();
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String firstNonBlank(String... values) {
        for (String v : values) {
            if (v != null && !v.isBlank()) {
                return v;
            }
        }
        return "ZAIRO";
    }

    static ByteArray handleOf(UUID userId) {
        ByteBuffer buffer = ByteBuffer.allocate(16);
        buffer.putLong(userId.getMostSignificantBits()).putLong(userId.getLeastSignificantBits());
        return new ByteArray(buffer.array());
    }

    static UUID uuidOf(ByteArray handle) {
        ByteBuffer buffer = ByteBuffer.wrap(handle.getBytes());
        return new UUID(buffer.getLong(), buffer.getLong());
    }

    /** The library's view of our storage. The "username" is always the user id (UUID string). */
    private final class Repo implements CredentialRepository {

        @Override
        public Set<PublicKeyCredentialDescriptor> getCredentialIdsForUsername(String username) {
            return Set.of(); // exclusion is added to the options explicitly in startRegistration
        }

        @Override
        public Optional<ByteArray> getUserHandleForUsername(String username) {
            try {
                return Optional.of(handleOf(UUID.fromString(username)));
            } catch (IllegalArgumentException e) {
                return Optional.empty();
            }
        }

        @Override
        public Optional<String> getUsernameForUserHandle(ByteArray userHandle) {
            try {
                return Optional.of(uuidOf(userHandle).toString());
            } catch (RuntimeException e) {
                return Optional.empty();
            }
        }

        @Override
        public Optional<RegisteredCredential> lookup(ByteArray credentialId, ByteArray userHandle) {
            return credentials.findByCredentialId(credentialId.getBytes())
                    .filter(c -> handleOf(c.getUserId()).equals(userHandle)).map(this::registered);
        }

        @Override
        public Set<RegisteredCredential> lookupAll(ByteArray credentialId) {
            return credentials.findByCredentialId(credentialId.getBytes()).map(this::registered).map(Set::of)
                    .orElse(Set.of());
        }

        private RegisteredCredential registered(PasskeyCredential c) {
            return RegisteredCredential.builder().credentialId(new ByteArray(c.getCredentialId()))
                    .userHandle(handleOf(c.getUserId())).publicKeyCose(new ByteArray(c.getPublicKeyCose()))
                    .signatureCount(c.getSignCount()).build();
        }
    }
}
