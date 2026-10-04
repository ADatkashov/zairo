package com.zairo.factory.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.users.UserRole;
import java.io.ByteArrayOutputStream;
import java.lang.reflect.Proxy;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.security.Signature;
import java.security.interfaces.ECPublicKey;
import java.security.spec.ECGenParameterSpec;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * End-to-end WebAuthn with a real Yubico verifier and a software
 * authenticator (ES256 key pair, "none" attestation) written below — so
 * registration and sign-in are verified for real (challenge, origin, RP-id
 * hash, signature), not mocked. Storage is in-memory fakes.
 */
class PasskeyServiceTest {

    private static final String RP_ID = "api.example.com";
    private static final String ORIGIN = "https://api.example.com";

    private final FakeCredentials credentials = new FakeCredentials();
    private final FakeCeremonies ceremonies = new FakeCeremonies();
    private final User user = new User(UUID.randomUUID(), "aigerim@example.com", null, "Aigerim", UserRole.CUSTOMER,
            Instant.parse("2026-01-01T00:00:00Z"));
    private final PasskeyService service = newService(RP_ID);

    private PasskeyService newService(String rpId) {
        UserRepository users = (UserRepository) Proxy.newProxyInstance(getClass().getClassLoader(),
                new Class<?>[] {UserRepository.class}, (proxy, method, args) -> {
                    if (method.getName().equals("findById")) {
                        return args[0].equals(user.getId()) ? Optional.of(user) : Optional.empty();
                    }
                    throw new UnsupportedOperationException(method.getName());
                });
        SessionIssuer issuer = new SessionIssuer(null, null) {
            @Override
            TokenResponse issue(User u) {
                return new TokenResponse("access", "refresh", SessionIssuer.toSummary(u));
            }
        };
        return new PasskeyService(credentials, ceremonies, users, issuer, new AuthAuditLog(),
                Clock.fixed(Instant.parse("2026-06-01T12:00:00Z"), ZoneOffset.UTC), rpId, "ZAIRO", "", "");
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> registerPasskey(SoftwareAuthenticator authenticator) throws Exception {
        PasskeyService.Started started = service.startRegistration(user.getId());
        Map<String, Object> credential = authenticator.createCredential(started.options(), ORIGIN);
        service.finishRegistration(user.getId(), started.ceremonyId(), credential, "Test phone");
        return credential;
    }

    @Test
    void aRegisteredPasskeySignsTheSameUserIn() throws Exception {
        SoftwareAuthenticator authenticator = new SoftwareAuthenticator(RP_ID);
        registerPasskey(authenticator);
        assertThat(service.list(user.getId())).extracting(PasskeyService.PasskeyView::name).containsExactly("Test phone");

        PasskeyService.Started login = service.startLogin();
        TokenResponse tokens = service.finishLogin(login.ceremonyId(),
                authenticator.getAssertion(login.options(), ORIGIN, user.getId(), false));

        assertThat(tokens.user().id()).isEqualTo(user.getId());
        assertThat(service.list(user.getId()).get(0).lastUsedAt()).isNotNull();
    }

    @Test
    void aForgedSignatureIsRejected() throws Exception {
        SoftwareAuthenticator authenticator = new SoftwareAuthenticator(RP_ID);
        registerPasskey(authenticator);
        PasskeyService.Started login = service.startLogin();

        Map<String, Object> assertion = authenticator.getAssertion(login.options(), ORIGIN, user.getId(), true);

        assertThatThrownBy(() -> service.finishLogin(login.ceremonyId(), assertion))
                .isInstanceOf(InvalidProviderCredentialException.class);
    }

    @Test
    void aSignatureFromAnUnregisteredKeyIsRejected() throws Exception {
        registerPasskey(new SoftwareAuthenticator(RP_ID));
        SoftwareAuthenticator stranger = new SoftwareAuthenticator(RP_ID);
        PasskeyService.Started login = service.startLogin();

        assertThatThrownBy(() -> service.finishLogin(login.ceremonyId(),
                stranger.getAssertion(login.options(), ORIGIN, user.getId(), false)))
                .isInstanceOf(InvalidProviderCredentialException.class);
    }

    @Test
    void anAssertionForAnotherOriginIsRejected() throws Exception {
        SoftwareAuthenticator authenticator = new SoftwareAuthenticator(RP_ID);
        registerPasskey(authenticator);
        PasskeyService.Started login = service.startLogin();

        assertThatThrownBy(() -> service.finishLogin(login.ceremonyId(),
                authenticator.getAssertion(login.options(), "https://evil.example.com", user.getId(), false)))
                .isInstanceOf(InvalidProviderCredentialException.class);
    }

    @Test
    void aCeremonyCanOnlyBeFinishedOnce() throws Exception {
        SoftwareAuthenticator authenticator = new SoftwareAuthenticator(RP_ID);
        registerPasskey(authenticator);
        PasskeyService.Started login = service.startLogin();
        Map<String, Object> assertion = authenticator.getAssertion(login.options(), ORIGIN, user.getId(), false);

        service.finishLogin(login.ceremonyId(), assertion);

        assertThatThrownBy(() -> service.finishLogin(login.ceremonyId(), assertion))
                .isInstanceOf(InvalidProviderCredentialException.class);
    }

    @Test
    void aRegistrationStartedByAnotherUserCannotBeFinished() throws Exception {
        SoftwareAuthenticator authenticator = new SoftwareAuthenticator(RP_ID);
        PasskeyService.Started started = service.startRegistration(user.getId());
        Map<String, Object> credential = authenticator.createCredential(started.options(), ORIGIN);

        assertThatThrownBy(() -> service.finishRegistration(UUID.randomUUID(), started.ceremonyId(), credential, null))
                .isInstanceOf(InvalidProviderCredentialException.class);
    }

    @Test
    void aPasskeyCanBeRemovedOnlyByItsOwner() throws Exception {
        registerPasskey(new SoftwareAuthenticator(RP_ID));
        UUID passkeyId = service.list(user.getId()).get(0).id();

        assertThatThrownBy(() -> service.delete(UUID.randomUUID(), passkeyId)).isInstanceOf(Exception.class);
        service.delete(user.getId(), passkeyId);
        assertThat(service.list(user.getId())).isEmpty();
    }

    @Test
    void passkeysAreOffWithoutAnRpId() {
        PasskeyService off = newService("");

        assertThat(off.isEnabled()).isFalse();
        assertThatThrownBy(off::startLogin).isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
    }

    @Test
    void androidOriginIsDerivedFromTheSigningCertFingerprint() {
        String fingerprint = "00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF";
        byte[] bytes = new byte[32];
        for (int i = 0; i < 32; i++) {
            bytes[i] = (byte) (i % 16 * 17);
        }

        assertThat(PasskeyService.allowedOrigins(RP_ID, fingerprint, "https://x.example.com")).containsExactly(
                "https://api.example.com",
                "android:apk-key-hash:" + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes),
                "https://x.example.com");
    }

    // ---- A software WebAuthn authenticator (ES256, "none" attestation) -----------

    private static final class SoftwareAuthenticator {
        private final String rpId;
        private final KeyPair keyPair;
        private final byte[] credentialId = new byte[32];
        private byte[] userHandle;
        private final ObjectMapper json = new ObjectMapper();
        private long signCount = 0;

        SoftwareAuthenticator(String rpId) throws Exception {
            this.rpId = rpId;
            KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
            generator.initialize(new ECGenParameterSpec("secp256r1"));
            this.keyPair = generator.generateKeyPair();
            new SecureRandom().nextBytes(credentialId);
        }

        Map<String, Object> createCredential(Map<String, Object> options, String origin) throws Exception {
            @SuppressWarnings("unchecked")
            Map<String, Object> user = (Map<String, Object>) options.get("user");
            userHandle = Base64.getUrlDecoder().decode((String) user.get("id"));
            String clientData = json.writeValueAsString(Map.of("type", "webauthn.create", "challenge",
                    options.get("challenge"), "origin", origin, "crossOrigin", false));

            ByteArrayOutputStream authData = new ByteArrayOutputStream();
            authData.write(sha256(rpId.getBytes(StandardCharsets.UTF_8)));
            authData.write(0x45); // user present + user verified + attested credential data
            authData.write(ByteBuffer.allocate(4).putInt(0).array());
            authData.write(new byte[16]); // AAGUID
            authData.write(ByteBuffer.allocate(2).putShort((short) credentialId.length).array());
            authData.write(credentialId);
            authData.write(coseKey());
            byte[] authDataBytes = authData.toByteArray();

            ByteArrayOutputStream attestation = new ByteArrayOutputStream();
            attestation.write(0xa3);
            attestation.write(cborText("fmt"));
            attestation.write(cborText("none"));
            attestation.write(cborText("attStmt"));
            attestation.write(0xa0);
            attestation.write(cborText("authData"));
            attestation.write(cborBytes(authDataBytes));

            Map<String, Object> response = new LinkedHashMap<>();
            response.put("clientDataJSON", b64(clientData.getBytes(StandardCharsets.UTF_8)));
            response.put("attestationObject", b64(attestation.toByteArray()));
            response.put("transports", List.of("internal"));
            return credential(response);
        }

        Map<String, Object> getAssertion(Map<String, Object> options, String origin, UUID expectedUser, boolean corrupt)
                throws Exception {
            String clientData = json.writeValueAsString(
                    Map.of("type", "webauthn.get", "challenge", options.get("challenge"), "origin", origin,
                            "crossOrigin", false));
            byte[] clientDataBytes = clientData.getBytes(StandardCharsets.UTF_8);
            signCount++;
            ByteArrayOutputStream authData = new ByteArrayOutputStream();
            authData.write(sha256(rpId.getBytes(StandardCharsets.UTF_8)));
            authData.write(0x05); // user present + user verified
            authData.write(ByteBuffer.allocate(4).putInt((int) signCount).array());
            byte[] authDataBytes = authData.toByteArray();

            Signature signature = Signature.getInstance("SHA256withECDSA");
            signature.initSign(keyPair.getPrivate());
            signature.update(authDataBytes);
            signature.update(sha256(clientDataBytes));
            byte[] sig = signature.sign();
            if (corrupt) {
                sig[sig.length - 1] ^= 0x01;
            }

            Map<String, Object> response = new LinkedHashMap<>();
            response.put("clientDataJSON", b64(clientDataBytes));
            response.put("authenticatorData", b64(authDataBytes));
            response.put("signature", b64(sig));
            response.put("userHandle", b64(userHandle != null ? userHandle : PasskeyService.handleOf(expectedUser).getBytes()));
            return credential(response);
        }

        private Map<String, Object> credential(Map<String, Object> response) {
            Map<String, Object> credential = new LinkedHashMap<>();
            credential.put("id", b64(credentialId));
            credential.put("rawId", b64(credentialId));
            credential.put("type", "public-key");
            credential.put("response", response);
            credential.put("clientExtensionResults", Map.of());
            return credential;
        }

        private byte[] coseKey() throws Exception {
            ECPublicKey pub = (ECPublicKey) keyPair.getPublic();
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            out.write(new byte[] {(byte) 0xa5, 0x01, 0x02, 0x03, 0x26, 0x20, 0x01});
            out.write(new byte[] {0x21, 0x58, 0x20});
            out.write(fixed32(pub.getW().getAffineX().toByteArray()));
            out.write(new byte[] {0x22, 0x58, 0x20});
            out.write(fixed32(pub.getW().getAffineY().toByteArray()));
            return out.toByteArray();
        }

        private static byte[] fixed32(byte[] bigEndian) {
            byte[] out = new byte[32];
            int length = Math.min(bigEndian.length, 32);
            System.arraycopy(bigEndian, bigEndian.length - length, out, 32 - length, length);
            return out;
        }

        private static byte[] cborText(String text) {
            byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            out.write(0x60 | bytes.length);
            out.writeBytes(bytes);
            return out.toByteArray();
        }

        private static byte[] cborBytes(byte[] bytes) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            out.write(0x58);
            out.write(bytes.length);
            out.writeBytes(bytes);
            return out.toByteArray();
        }

        private static byte[] sha256(byte[] data) throws Exception {
            return MessageDigest.getInstance("SHA-256").digest(data);
        }

        private static String b64(byte[] data) {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(data);
        }
    }

    // ---- In-memory storage ---------------------------------------------------------

    private static final class FakeCredentials implements PasskeyCredentialRepository {
        private final List<PasskeyCredential> rows = new ArrayList<>();

        @Override
        public PasskeyCredential save(PasskeyCredential credential) {
            if (!rows.contains(credential)) {
                rows.add(credential);
            }
            return credential;
        }

        @Override
        public Optional<PasskeyCredential> findById(UUID id) {
            return rows.stream().filter(c -> c.getId().equals(id)).findFirst();
        }

        @Override
        public Optional<PasskeyCredential> findByCredentialId(byte[] credentialId) {
            return rows.stream().filter(c -> java.util.Arrays.equals(c.getCredentialId(), credentialId)).findFirst();
        }

        @Override
        public List<PasskeyCredential> findByUserIdOrderByCreatedAtAsc(UUID userId) {
            return rows.stream().filter(c -> c.getUserId().equals(userId)).toList();
        }

        @Override
        public void delete(PasskeyCredential credential) {
            rows.remove(credential);
        }
    }

    private static final class FakeCeremonies implements WebauthnCeremonyRepository {
        private final Map<UUID, WebauthnCeremony> rows = new LinkedHashMap<>();

        @Override
        public WebauthnCeremony save(WebauthnCeremony ceremony) {
            rows.put(ceremony.getId(), ceremony);
            return ceremony;
        }

        @Override
        public Optional<WebauthnCeremony> findById(UUID id) {
            return Optional.ofNullable(rows.get(id));
        }

        @Override
        public int consume(UUID id) {
            return rows.remove(id) == null ? 0 : 1;
        }

        @Override
        public int deleteExpired(Instant now) {
            return 0;
        }
    }
}
