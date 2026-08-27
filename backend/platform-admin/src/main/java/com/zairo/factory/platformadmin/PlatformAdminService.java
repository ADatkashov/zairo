package com.zairo.factory.platformadmin;

import com.zairo.factory.platformadmin.PlatformAdminDtos.AdminSummary;
import com.zairo.factory.platformadmin.PlatformAdminDtos.CreateAdminRequest;
import com.zairo.factory.platformadmin.PlatformAdminDtos.TokenResponse;
import java.time.Instant;
import java.util.UUID;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlatformAdminService {

    private final PlatformAdminAccountRepository accountRepository;
    private final PlatformAdminJwtService jwtService;
    private final PlatformAuditLogService auditLogService;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public PlatformAdminService(PlatformAdminAccountRepository accountRepository, PlatformAdminJwtService jwtService,
            PlatformAuditLogService auditLogService) {
        this.accountRepository = accountRepository;
        this.jwtService = jwtService;
        this.auditLogService = auditLogService;
    }

    @Transactional
    public TokenResponse login(String email, String rawPassword) {
        PlatformAdminAccount account = accountRepository.findByEmail(email)
                .orElseThrow(() -> new InvalidPlatformCredentialsException("Invalid email or password"));
        if (!account.isActive() || !passwordEncoder.matches(rawPassword, account.getPasswordHash())) {
            throw new InvalidPlatformCredentialsException("Invalid email or password");
        }
        String accessToken = jwtService.issueAccessToken(account.getId(), account.getRole().name());
        return new TokenResponse(accessToken, AdminSummary.from(account));
    }

    public AdminSummary me(UUID adminId) {
        PlatformAdminAccount account = accountRepository.findById(adminId)
                .orElseThrow(() -> new InvalidPlatformCredentialsException("Account no longer exists"));
        return AdminSummary.from(account);
    }

    /**
     * PLATFORM_ADMIN-only (enforced by the controller before this is
     * called) — there's no public self-registration for platform accounts,
     * same as the customer side's ADMIN role: the very first row is
     * inserted directly in the database, every one after that is created by
     * an existing PLATFORM_ADMIN through this method.
     */
    @Transactional
    public AdminSummary createAdmin(UUID actorId, String actorEmail, CreateAdminRequest request) {
        if (accountRepository.findByEmail(request.email()).isPresent()) {
            throw new PlatformAdminEmailAlreadyRegisteredException(
                    "Email already registered: " + request.email());
        }
        PlatformAdminAccount account = new PlatformAdminAccount(UUID.randomUUID(), request.email(),
                passwordEncoder.encode(request.password()), request.displayName(), request.role(), Instant.now());
        account = accountRepository.save(account);

        auditLogService.record(actorId, actorEmail, "PLATFORM_ADMIN_CREATED", "PLATFORM_ADMIN_ACCOUNT",
                account.getId(), null, request.role().name(), request.reason());

        return AdminSummary.from(account);
    }
}
