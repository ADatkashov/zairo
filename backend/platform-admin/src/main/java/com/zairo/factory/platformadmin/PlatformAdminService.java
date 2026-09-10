package com.zairo.factory.platformadmin;

import com.zairo.factory.platformadmin.PlatformAdminDtos.AdminSummary;
import com.zairo.factory.platformadmin.PlatformAdminDtos.CreateAdminRequest;
import com.zairo.factory.platformadmin.PlatformAdminDtos.TokenResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

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

    /**
     * Same owner-writes-their-own-account shape as the customer/business
     * side's AuthService.updateAvatar: no ownership check beyond "this is
     * the caller's own account", which PlatformCurrentAdmin.requireAdminId
     * already guarantees at the controller. Not audit-logged — a personal
     * profile photo isn't a platform-wide mutation the way createAdmin/
     * deactivateAdmin are.
     */
    @Transactional
    public AdminSummary updateAvatar(UUID adminId, String avatarUrl) {
        PlatformAdminAccount account = accountRepository.findById(adminId)
                .orElseThrow(() -> new InvalidPlatformCredentialsException("Account no longer exists"));
        account.updateAvatar(avatarUrl);
        return AdminSummary.from(accountRepository.save(account));
    }

    /** PLATFORM_ADMIN-only (enforced by the controller) — every platform staff account, active or not. */
    public List<AdminSummary> listAdmins() {
        return accountRepository.findAll().stream().map(AdminSummary::from).toList();
    }

    /**
     * Soft-revoke: PLATFORM_ADMIN-only. Idempotent — deactivating an
     * already-inactive account is a no-op (still audit-logged, since an
     * explicit repeat action is itself worth a trail entry).
     */
    @Transactional
    public AdminSummary deactivateAdmin(UUID actorId, String actorEmail, UUID targetAdminId, String reason) {
        PlatformAdminAccount account = getAccount(targetAdminId);
        if (actorId.equals(targetAdminId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot deactivate your own account");
        }
        account.deactivate();
        account = accountRepository.save(account);
        auditLogService.record(actorId, actorEmail, "PLATFORM_ADMIN_DEACTIVATED", "PLATFORM_ADMIN_ACCOUNT",
                account.getId(), "active", "inactive", reason);
        return AdminSummary.from(account);
    }

    /** PLATFORM_ADMIN-only, idempotent — undoes deactivateAdmin(). */
    @Transactional
    public AdminSummary reactivateAdmin(UUID actorId, String actorEmail, UUID targetAdminId, String reason) {
        PlatformAdminAccount account = getAccount(targetAdminId);
        account.reactivate();
        account = accountRepository.save(account);
        auditLogService.record(actorId, actorEmail, "PLATFORM_ADMIN_REACTIVATED", "PLATFORM_ADMIN_ACCOUNT",
                account.getId(), "inactive", "active", reason);
        return AdminSummary.from(account);
    }

    private PlatformAdminAccount getAccount(UUID adminId) {
        return accountRepository.findById(adminId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Admin not found: " + adminId));
    }
}
