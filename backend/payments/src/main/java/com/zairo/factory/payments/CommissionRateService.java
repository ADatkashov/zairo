package com.zairo.factory.payments;

import com.zairo.factory.catalog.BusinessTypeRepository;
import com.zairo.factory.catalog.Category;
import com.zairo.factory.catalog.CategoryRepository;
import com.zairo.factory.payments.CommissionDtos.CategoryCommission;
import com.zairo.factory.payments.CommissionDtos.CommissionSettingsResponse;
import com.zairo.factory.platformadmin.PlatformAuditLogService;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Which commission rate applies to a booking, and the PLATFORM_ADMIN edits
 * that change it. Resolution: the provider's business type -> its catalog
 * category -> that category's own rate if one is set, otherwise the
 * platform-wide default (0% until an admin raises it). Every edit is
 * audit-logged. Rates are stored as fractions (0.10 = 10%) and exposed to
 * admins as percent.
 */
@Service
public class CommissionRateService {

    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);

    private final CommissionRateRepository rateRepository;
    private final CategoryRepository categoryRepository;
    private final BusinessTypeRepository businessTypeRepository;
    private final ProviderRepository providerRepository;
    private final PlatformAuditLogService auditLogService;

    CommissionRateService(CommissionRateRepository rateRepository, CategoryRepository categoryRepository,
            BusinessTypeRepository businessTypeRepository, ProviderRepository providerRepository,
            PlatformAuditLogService auditLogService) {
        this.rateRepository = rateRepository;
        this.categoryRepository = categoryRepository;
        this.businessTypeRepository = businessTypeRepository;
        this.providerRepository = providerRepository;
        this.auditLogService = auditLogService;
    }

    /** The fraction (0..1) to apply to a payment for this provider's booking. */
    @Transactional(readOnly = true)
    BigDecimal rateForProvider(UUID providerId) {
        Optional<UUID> categoryId = providerRepository.findById(providerId).map(Provider::getBusinessTypeId)
                .flatMap(businessTypeRepository::findById).map(bt -> bt.getCategoryId());
        return categoryId.flatMap(rateRepository::findByCategoryId).map(CommissionRate::getRate)
                .orElseGet(this::defaultRate);
    }

    @Transactional(readOnly = true)
    public CommissionSettingsResponse settings() {
        BigDecimal defaultRate = defaultRate();
        Map<UUID, BigDecimal> overrides = rateRepository.findAll().stream().filter(r -> r.getCategoryId() != null)
                .collect(Collectors.toMap(CommissionRate::getCategoryId, CommissionRate::getRate));
        List<CategoryCommission> categories = categoryRepository.findAllByOrderBySortOrderAsc().stream()
                .map(c -> toDto(c, overrides.get(c.getId()), defaultRate)).toList();
        return new CommissionSettingsResponse(toPercent(defaultRate), categories);
    }

    @Transactional
    public CommissionSettingsResponse setDefault(UUID actorId, String actorEmail, BigDecimal percent) {
        CommissionRate row = rateRepository.findByCategoryIdIsNull()
                .orElseThrow(() -> new IllegalStateException("Default commission row is missing (see V91)"));
        BigDecimal previous = row.getRate();
        row.changeRate(toFraction(percent), Instant.now(), actorEmail);
        rateRepository.save(row);
        auditLogService.record(actorId, actorEmail, "COMMISSION_DEFAULT_SET", "COMMISSION_RATE", row.getId(),
                toPercent(previous).toPlainString(), percent.toPlainString(), null);
        return settings();
    }

    @Transactional
    public CommissionSettingsResponse setCategory(UUID actorId, String actorEmail, UUID categoryId,
            BigDecimal percent) {
        requireCategory(categoryId);
        BigDecimal fraction = toFraction(percent);
        Optional<CommissionRate> existing = rateRepository.findByCategoryId(categoryId);
        String previous = existing.map(r -> toPercent(r.getRate()).toPlainString()).orElse(null);
        CommissionRate row;
        if (existing.isPresent()) {
            row = existing.get();
            row.changeRate(fraction, Instant.now(), actorEmail);
        } else {
            row = new CommissionRate(UUID.randomUUID(), categoryId, fraction, Instant.now(), actorEmail);
        }
        rateRepository.save(row);
        auditLogService.record(actorId, actorEmail, "COMMISSION_CATEGORY_SET", "CATEGORY", categoryId, previous,
                percent.toPlainString(), null);
        return settings();
    }

    /** Removes the override so the category follows the platform default again. */
    @Transactional
    public CommissionSettingsResponse clearCategory(UUID actorId, String actorEmail, UUID categoryId) {
        requireCategory(categoryId);
        rateRepository.findByCategoryId(categoryId).ifPresent(row -> {
            rateRepository.delete(row);
            auditLogService.record(actorId, actorEmail, "COMMISSION_CATEGORY_CLEARED", "CATEGORY", categoryId,
                    toPercent(row.getRate()).toPlainString(), null, null);
        });
        return settings();
    }

    private BigDecimal defaultRate() {
        return rateRepository.findByCategoryIdIsNull().map(CommissionRate::getRate).orElse(BigDecimal.ZERO);
    }

    private void requireCategory(UUID categoryId) {
        if (!categoryRepository.existsById(categoryId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found: " + categoryId);
        }
    }

    private static CategoryCommission toDto(Category c, BigDecimal override, BigDecimal defaultRate) {
        return new CategoryCommission(c.getId(), c.getCode(), c.getNameKk(), c.getNameRu(), c.getNameEn(),
                override == null ? null : toPercent(override), toPercent(override == null ? defaultRate : override));
    }

    private static BigDecimal toFraction(BigDecimal percent) {
        return percent.divide(HUNDRED, 4, RoundingMode.HALF_UP);
    }

    private static BigDecimal toPercent(BigDecimal fraction) {
        return fraction.multiply(HUNDRED).setScale(2, RoundingMode.HALF_UP);
    }
}
