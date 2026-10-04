package com.zairo.factory.auth;

import com.zairo.factory.auth.AuthDtos.TokenResponse;
import com.zairo.factory.auth.AuthDtos.UserSummary;
import com.zairo.factory.auth.FacebookIdentityVerifierPort.VerifiedIdentity;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.users.UserRole;
import com.zairo.factory.auth.AuthDtos.PhoneStatusResponse;
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
 * no second user table and no per-provider shadow account. Two identities
 * end up on the same {@code app_user} when (a) they were created together,
 * (b) an authenticated user called one of the {@code link*} methods,
 * (c) a provider-verified email matches an account whose email is already
 * verified, or (d) the person proved ownership with that account's
 * password ({@link #linkProviderWithPassword}). An email that was merely
 * typed in is never enough by itself (account pre-hijacking).
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
    private final LoginAttemptLimiter loginAttemptLimiter;
    private final RefreshTokenService refreshTokenService;

    IdentityService(UserRepository userRepository, IdentityLookupService identityLookupService,
            PhoneOtpService phoneOtpService, PhoneNumberNormalizer phoneNumberNormalizer,
            GoogleIdTokenVerifierPort googleVerifier, FacebookIdentityVerifierPort facebookVerifier,
            SessionIssuer sessionIssuer, AuthAuditLog auditLog, LoginAttemptLimiter loginAttemptLimiter,
            RefreshTokenService refreshTokenService) {
        this.userRepository = userRepository;
        this.identityLookupService = identityLookupService;
        this.phoneOtpService = phoneOtpService;
        this.phoneNumberNormalizer = phoneNumberNormalizer;
        this.googleVerifier = googleVerifier;
        this.facebookVerifier = facebookVerifier;
        this.sessionIssuer = sessionIssuer;
        this.auditLog = auditLog;
        this.loginAttemptLimiter = loginAttemptLimiter;
        this.refreshTokenService = refreshTokenService;
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

    // ---- Phone + password (SMS only for registration / forgotten password) -------

    /**
     * Tells the app which screen to show after a phone number is typed:
     * a password prompt for an existing account, or the SMS registration
     * flow. This deliberately reveals whether a phone is registered — the
     * product asked for the "enter number, then password" UX every phone
     * app has — so it is the one place that does; request-otp itself still
     * doesn't.
     */
    public PhoneStatusResponse phoneStatus(String rawPhone) {
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        Optional<User> user = identityLookupService.findExisting(IdentityProvider.PHONE, phone);
        return new PhoneStatusResponse(user.isPresent(),
                user.isPresent() && identityLookupService.hasPassword(user.get().getId()));
    }

    public TokenResponse loginWithPhonePassword(String rawPhone, String password) {
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        String limiterKey = "phone:" + phone;
        loginAttemptLimiter.checkNotLockedOut(limiterKey);
        Optional<User> user = identityLookupService.findExisting(IdentityProvider.PHONE, phone);
        if (user.isEmpty() || !identityLookupService.passwordMatches(user.get().getId(), password)) {
            loginAttemptLimiter.recordFailure(limiterKey);
            auditLog.loginFailed("PHONE_PASSWORD", "invalid_credentials");
            throw new InvalidCredentialsException("Invalid phone or password");
        }
        loginAttemptLimiter.recordSuccess(limiterKey);
        auditLog.loginSucceeded(user.get().getId(), "PHONE_PASSWORD");
        return sessionIssuer.issue(user.get());
    }

    /** First-time registration: SMS code proves the phone, the person chooses their name and password. */
    public TokenResponse registerWithPhone(String rawPhone, String code, String displayName, String password) {
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        verifyOtpOrAudit(phone, code);
        if (identityLookupService.findExisting(IdentityProvider.PHONE, phone).isPresent()) {
            throw new IdentityAlreadyLinkedException("This phone already has an account - sign in with its password");
        }
        User user;
        try {
            user = identityLookupService.createPhoneUserWithPassword(phone, displayName.trim(), password);
        } catch (DataIntegrityViolationException raceLoser) {
            throw new IdentityAlreadyLinkedException("This phone already has an account - sign in with its password");
        }
        auditLog.loginSucceeded(user.getId(), "PHONE");
        return sessionIssuer.issue(user);
    }

    /**
     * Forgotten password (or an account that never had one): the SMS code
     * proves the phone, which is a verified identity of exactly one
     * account. Revokes other sessions, same as the email reset flow.
     */
    public void resetPasswordWithPhone(String rawPhone, String code, String newPassword) {
        String phone = phoneNumberNormalizer.normalize(rawPhone);
        verifyOtpOrAudit(phone, code);
        User user = identityLookupService.findExisting(IdentityProvider.PHONE, phone)
                .orElseThrow(() -> new InvalidOtpException("Invalid or expired code"));
        identityLookupService.setPassword(user.getId(), newPassword);
        refreshTokenService.revokeAllForUser(user.getId());
        loginAttemptLimiter.recordSuccess("phone:" + phone);
    }

    // ---- Connecting Google/Facebook to an account that owns the same email ---

    /**
     * The answer to {@link AccountLinkRequiredException}: the person proves
     * they own the existing (email+password) account by its password, and
     * only then is the Google/Facebook identity attached to it. The email
     * is now proven twice over (provider + password), so it is marked
     * verified and later provider logins link without asking again.
     */
    public TokenResponse linkProviderWithPassword(IdentityProvider provider, String token, String password) {
        String subject;
        String email;
        switch (provider) {
            case GOOGLE -> {
                GoogleIdTokenVerifierPort.VerifiedIdentity identity = googleVerifier.verify(token)
                        .orElseThrow(() -> new InvalidProviderCredentialException("Invalid Google credential"));
                subject = identity.subject();
                email = identity.emailVerified() ? identity.email() : null;
            }
            case FACEBOOK -> {
                VerifiedIdentity identity = facebookVerifier.verify(token)
                        .orElseThrow(() -> new InvalidProviderCredentialException("Invalid Facebook credential"));
                subject = identity.subject();
                email = identity.emailVerified() ? identity.email() : null;
            }
            default -> throw new InvalidProviderCredentialException("Unsupported provider");
        }
        if (email == null) {
            throw new InvalidProviderCredentialException("The provider did not confirm an email for this account");
        }
        String limiterKey = "link:" + email;
        loginAttemptLimiter.checkNotLockedOut(limiterKey);
        User owner = userRepository.findByEmail(email).orElse(null);
        if (owner == null || !identityLookupService.passwordMatches(owner.getId(), password)) {
            loginAttemptLimiter.recordFailure(limiterKey);
            throw new InvalidCredentialsException("Invalid email or password");
        }
        loginAttemptLimiter.recordSuccess(limiterKey);
        linkIdentity(owner.getId(), provider, subject, null);
        identityLookupService.markEmailVerified(owner.getId());
        auditLog.identityLinked(owner.getId(), provider);
        return sessionIssuer.issue(owner);
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
     * CUSTOMER account for it. The one case where a new identity joins an
     * existing account on its own is a provider-verified email that an
     * account already holds as a <i>verified</i> email (one customer, many
     * sign-in methods); an unverified match needs the account's password
     * first (see {@link AccountLinkRequiredException}), so nobody can
     * inherit a login by pre-registering someone else's email.
     */
    private User findOrCreateUser(IdentityProvider provider, String subject, String verifiedEmail,
            String phoneForDisplay, String displayName) {
        Optional<User> existing = identityLookupService.findExisting(provider, subject);
        if (existing.isPresent()) {
            return existing.get();
        }
        if (verifiedEmail != null) {
            Optional<User> sameEmail = userRepository.findByEmail(verifiedEmail);
            if (sameEmail.isPresent()) {
                User owner = sameEmail.get();
                if (!owner.isEmailVerified()) {
                    // Its email was only ever typed in, never proven: the
                    // caller must confirm that account's password first.
                    throw new AccountLinkRequiredException();
                }
                // Same customer: that email was already proven through
                // another provider, so this identity joins the same account.
                linkIdentity(owner.getId(), provider, subject, null);
                auditLog.identityLinked(owner.getId(), provider);
                return owner;
            }
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
