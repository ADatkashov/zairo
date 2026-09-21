package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.auth.FacebookIdentityVerifierPort.VerifiedIdentity;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.users.UserRole;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Orchestrates Google / Facebook / phone-OTP sign-in and account linking on
 * top of the single, existing identity model ({@link UserIdentity}) — see
 * CLAUDE.md task spec §2. Every path below ends the same way password login
 * does: a {@link User} row and a {@link SessionIssuer#issue} call. There is
 * no second user table, no per-provider shadow account, and no automatic
 * merging of two accounts just because they share an email (task spec §8)
 * — the only two ways two identities end up on the same {@code app_user}
 * are (a) they always were (created together) or (b) an authenticated user
 * explicitly called one of the {@code link*} methods below.
 */
@Service
public class IdentityService {

    private static final String FALLBACK_DISPLAY_NAME = "ZAIRO User";

    private final UserRepository userRepository;
    private final IdentityLookupService identityLookupService;
    private final PhoneOtpService phoneOtpService;
    private final PhoneNumberNormalizer phoneNumberNormalizer;
    private final GoogleIdTokenVerifierPort googleVerifier;
    private final FacebookIdentityVerifierPort facebookVerifier;
    private final SessionIssuer sessionIssuer;
    private final AuthAuditLog auditLog;

    IdentityService(UserRepository userRepository, IdentityLookupService identityLookupService,
            PhoneOtpService phoneOtpService, PhoneNumberNormalizer phoneNumberNormalizer,
            GoogleIdTokenVerifierPort googleVerifier, FacebookIdentityVerifierPort facebookVerifier,
            SessionIssuer sessionIssuer, AuthAuditLog auditLog) {
        this.userRepository = userRepository;
        this.identityLookupService = identityLookupService;
        this.phoneOtpService = phoneOtpService;
        this.phoneNumberNormalizer = phoneNumberNormalizer;
        this.googleVerifier = googleVerifier;
        this.facebookVerifier = facebookVerifier;
        this.sessionIssuer = sessionIssuer;
        this.auditLog = auditLog;
    }

    // ---- Google ------------------------------------------------------

    public TokenResponse loginOrRegisterWithGoogle(String idToken) {
        GoogleIdTokenVerifierPort.VerifiedIdentity identity = googleVerifier.verify(idToken).orElseThrow(() -> {
            auditLog.loginFailed("GOOGLE", "invalid_credential");
            return new InvalidProviderCredentialException("Invalid Google credential");
        });
        User user = findOrCreateUser(IdentityProvider.GOOGLE, identity.subject(),
                identity.emailVerified() ? identity.email() : null, null, identity.displayName());
        auditLog.loginSucceeded(user.getId(), "GOOGLE");
        return sessionIssuer.issue(user);
    }

    public UserSummary linkGoogle(UUID currentUserId, String idToken) {
        GoogleIdTokenVerifierPort.VerifiedIdentity identity = googleVerifier.verify(idToken).orElseThrow(() -> {
            auditLog.loginFailed("GOOGLE", "invalid_credential");
            return new InvalidProviderCredentialException("Invalid Google credential");
        });
        linkIdentity(currentUserId, IdentityProvider.GOOGLE, identity.subject(), null);
        auditLog.identityLinked(currentUserId, IdentityProvider.GOOGLE);
        return SessionIssuer.toSummary(requireUser(currentUserId));
    }

    // ---- Facebook ------------------------------------------------------

    public TokenResponse loginOrRegisterWithFacebook(String accessToken) {
        VerifiedIdentity identity = facebookVerifier.verify(accessToken).orElseThrow(() -> {
            auditLog.loginFailed("FACEBOOK", "invalid_credential");
            return new InvalidProviderCredentialException("Invalid Facebook credential");
        });
        User user = findOrCreateUser(IdentityProvider.FACEBOOK, identity.subject(),
                identity.emailVerified() ? identity.email() : null, null, identity.displayName());
        auditLog.loginSucceeded(user.getId(), "FACEBOOK");
        return sessionIssuer.issue(user);
    }

    public UserSummary linkFacebook(UUID currentUserId, String accessToken) {
        VerifiedIdentity identity = facebookVerifier.verify(accessToken).orElseThrow(() -> {
            auditLog.loginFailed("FACEBOOK", "invalid_credential");
            return new InvalidProviderCredentialException("Invalid Facebook credential");
        });
        linkIdentity(currentUserId, IdentityProvider.FACEBOOK, identity.subject(), null);
        auditLog.identityLinked(currentUserId, IdentityProvider.FACEBOOK);
        return SessionIssuer.toSummary(requireUser(currentUserId));
    }

    // ---- Phone + OTP ---------------------------------------------------

    /**
     * Always succeeds from the caller's point of view regardless of whether
     * this phone already has an account — see task spec §7 on not revealing
     * registration status through this endpoint. Rate limiting/cooldown
     * failures (see PhoneOtpService) are the one exception: those *are*
     * surfaced, because they're about this phone number being hammered,
     * not about whether it's registered.
     */
    public void requestPhoneOtp(String rawPhone) {
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        phoneOtpService.requestOtp(phone);
        auditLog.otpRequested();
    }

    public TokenResponse loginOrRegisterWithPhone(String rawPhone, String code) {
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        verifyOtpOrAudit(phone, code);
        User user = findOrCreateUser(IdentityProvider.PHONE, phone, null, phone, phone);
        auditLog.loginSucceeded(user.getId(), "PHONE");
        return sessionIssuer.issue(user);
    }

    public UserSummary linkPhone(UUID currentUserId, String rawPhone, String code) {
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        verifyOtpOrAudit(phone, code);
        linkIdentity(currentUserId, IdentityProvider.PHONE, phone, phone);
        auditLog.identityLinked(currentUserId, IdentityProvider.PHONE);
        return SessionIssuer.toSummary(requireUser(currentUserId));
    }

    private void verifyOtpOrAudit(String phone, String code) {
        try {
            phoneOtpService.verify(phone, code);
        } catch (RuntimeException e) {
            auditLog.otpVerificationFailed(e.getClass().getSimpleName());
            throw e;
        }
    }

    // ---- Shared ---------------------------------------------------------

    /** What's linked to the caller's own account, and when — for a Settings > Security screen. */
    public List<AuthDtos.IdentitySummary> listIdentities(UUID userId) {
        return identityLookupService.findIdentitiesForUser(userId).stream()
                .map(identity -> new AuthDtos.IdentitySummary(identity.getProvider(), identity.getCreatedAt()))
                .toList();
    }

    /**
     * Finds the user this identity already belongs to, or creates a new
     * CUSTOMER account for it — never both merges with, nor silently
     * attaches to, an unrelated existing account (task spec §8/§9).
     */
    private User findOrCreateUser(IdentityProvider provider, String subject, String verifiedEmail,
            String phoneForDisplay, String displayName) {
        Optional<User> existing = identityLookupService.findExisting(provider, subject);
        if (existing.isPresent()) {
            return existing.get();
        }
        String name = displayName != null && !displayName.isBlank() ? displayName : FALLBACK_DISPLAY_NAME;
        try {
            return identityLookupService.createUserWithIdentity(provider, subject, verifiedEmail, phoneForDisplay,
                    name, UserRole.CUSTOMER);
        } catch (DataIntegrityViolationException raceLoser) {
            // A concurrent first-time login for this exact identity won
            // the race and committed first (see IdentityLookupService's
            // doc comment) — this is now just a login.
            return identityLookupService.findExisting(provider, subject)
                    .orElseThrow(() -> new IdentityAlreadyLinkedException(
                            "This " + provider + " identity is already linked to another account"));
        }
    }

    private void linkIdentity(UUID userId, IdentityProvider provider, String subject, String phoneForDisplay) {
        Optional<User> owner = identityLookupService.findExisting(provider, subject);
        if (owner.isPresent()) {
            if (owner.get().getId().equals(userId)) {
                return; // Already linked to the caller — idempotent.
            }
            throw new IdentityAlreadyLinkedException(
                    "This " + provider + " identity is already linked to another account");
        }
        try {
            identityLookupService.attachIdentity(userId, provider, subject, phoneForDisplay);
        } catch (DataIntegrityViolationException race) {
            Optional<User> raced = identityLookupService.findExisting(provider, subject);
            if (raced.isPresent() && raced.get().getId().equals(userId)) {
                return; // Two concurrent link attempts for the caller's own identity — harmless.
            }
            throw new IdentityAlreadyLinkedException(
                    "This " + provider + " identity is already linked to another account");
        }
    }

    private User requireUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User no longer exists"));
    }
}
