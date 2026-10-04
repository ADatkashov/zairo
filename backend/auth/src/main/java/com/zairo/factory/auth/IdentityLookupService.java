package com.zairo.factory.auth;

import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import com.zairo.factory.users.UserRole;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * The transactional core behind {@link IdentityService} — split into its
 * own bean specifically so each method below runs in its <b>own</b>
 * database transaction via Spring's real proxy. IdentityService itself is
 * deliberately <i>not</i> {@code @Transactional}: calling a
 * {@code @Transactional} method on {@code this} from within the same class
 * bypasses the proxy entirely (a well-known Spring pitfall), which would
 * silently defeat the retry-after-unique-violation logic below. Going
 * through a separate bean is what makes "transaction A fails and rolls
 * back, transaction B (a plain re-read) then runs against a clean
 * connection" actually true — see {@link IdentityService}'s
 * {@code findOrCreateUser}/{@code linkIdentity} for why that matters: two
 * concurrent first-time logins (or two concurrent link attempts) for the
 * *same* provider identity must not create two accounts (or attach the
 * same identity to two different owners) — see CLAUDE.md task spec §9's
 * "database должна быть последним уровнем защиты после application-level
 * checks."
 */
@Component
class IdentityLookupService {

    private final UserRepository userRepository;
    private final UserIdentityRepository userIdentityRepository;
    private final CredentialRepository credentialRepository;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    IdentityLookupService(UserRepository userRepository, UserIdentityRepository userIdentityRepository,
            CredentialRepository credentialRepository) {
        this.userRepository = userRepository;
        this.userIdentityRepository = userIdentityRepository;
        this.credentialRepository = credentialRepository;
    }

    @Transactional(readOnly = true)
    boolean hasPassword(UUID userId) {
        return credentialRepository.findByUserId(userId).isPresent();
    }

    /** True if {@code rawPassword} matches the user's password; false if wrong or the user has none. */
    @Transactional(readOnly = true)
    boolean passwordMatches(UUID userId, String rawPassword) {
        return credentialRepository.findByUserId(userId)
                .map(c -> passwordEncoder.matches(rawPassword, c.getPasswordHash())).orElse(false);
    }

    /** Sets (or creates) the user's password — covers accounts that so far only had Google/Facebook/phone. */
    @Transactional
    void setPassword(UUID userId, String rawPassword) {
        String hash = passwordEncoder.encode(rawPassword);
        Credential credential = credentialRepository.findByUserId(userId).orElse(null);
        if (credential == null) {
            credentialRepository.save(new Credential(UUID.randomUUID(), userId, hash, Instant.now()));
        } else {
            credential.changePasswordHash(hash);
            credentialRepository.save(credential);
        }
    }

    @Transactional
    void markEmailVerified(UUID userId) {
        User user = userRepository.findById(userId).orElseThrow();
        if (!user.isEmailVerified()) {
            user.markEmailVerified();
            userRepository.save(user);
        }
    }

    /**
     * Phone registration: user, PHONE identity and password in one
     * transaction, so a half-created account (phone but no password) can't
     * be left behind. Same unique-constraint race semantics as
     * {@link #createUserWithIdentity}.
     */
    @Transactional
    User createPhoneUserWithPassword(String e164Phone, String displayName, String rawPassword) {
        User user = createUserWithIdentity(IdentityProvider.PHONE, e164Phone, null, e164Phone, displayName,
                UserRole.CUSTOMER);
        credentialRepository.save(new Credential(UUID.randomUUID(), user.getId(),
                passwordEncoder.encode(rawPassword), Instant.now()));
        return user;
    }

    @Transactional(readOnly = true)
    Optional<User> findExisting(IdentityProvider provider, String providerSubject) {
        return userIdentityRepository.findByProviderAndProviderSubject(provider, providerSubject)
                .flatMap(identity -> userRepository.findById(identity.getUserId()));
    }

    @Transactional(readOnly = true)
    List<UserIdentity> findIdentitiesForUser(UUID userId) {
        return userIdentityRepository.findByUserId(userId);
    }

    /**
     * @throws EmailAlreadyRegisteredException {@code email} is non-null and already belongs to another account —
     *         see IdentityService's doc comment on why this never auto-merges.
     * @throws org.springframework.dao.DataIntegrityViolationException the unique {@code (provider,
     *         provider_subject)} constraint was violated — a concurrent request won the race to create this exact
     *         identity first. Caller (IdentityService) retries as a lookup once this rolls back.
     */
    @Transactional
    User createUserWithIdentity(IdentityProvider provider, String providerSubject, String email,
            String phoneForDisplay, String displayName, UserRole role) {
        if (email != null) {
            userRepository.findByEmail(email).ifPresent(existing -> {
                throw new EmailAlreadyRegisteredException(
                        "An account with this email already exists. Log in with your existing method, then link "
                                + "this one from Settings.");
            });
        }
        User user = new User(UUID.randomUUID(), email, phoneForDisplay, displayName, role, Instant.now());
        if (email != null) {
            // Only provider-verified emails reach this method (see IdentityService).
            user.markEmailVerified();
        }
        user = userRepository.save(user);
        // saveAndFlush forces the INSERT (and any unique-constraint
        // violation) to happen now, inside this method's own transaction,
        // rather than being deferred to commit time after this method has
        // already returned — see this class's own doc comment.
        userIdentityRepository.saveAndFlush(
                new UserIdentity(UUID.randomUUID(), user.getId(), provider, providerSubject, Instant.now()));
        return user;
    }

    /** @throws org.springframework.dao.DataIntegrityViolationException same race as createUserWithIdentity. */
    @Transactional
    void attachIdentity(UUID userId, IdentityProvider provider, String providerSubject, String phoneForDisplay) {
        userIdentityRepository.saveAndFlush(
                new UserIdentity(UUID.randomUUID(), userId, provider, providerSubject, Instant.now()));
        if (phoneForDisplay != null) {
            User user = userRepository.findById(userId).orElseThrow();
            user.adoptPhoneIfMissing(phoneForDisplay);
            userRepository.save(user);
        }
    }
}
