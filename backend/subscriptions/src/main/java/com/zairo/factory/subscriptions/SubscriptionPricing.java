package com.zairo.factory.subscriptions;

import com.zairo.factory.platformadmin.PlatformAuditLogService;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * What PRO costs, read wherever a charge or a price is shown. The platform sets it (PLATFORM_ADMIN, audit-logged);
 * until it does, the built-in {@link SubscriptionPlan#monthlyPrice} in {@code app.platform.default-currency} applies
 * exactly as before, so deploying this changes nothing by itself.
 */
@Service
public class SubscriptionPricing {

    /** An amount and its ISO 4217 currency. */
    public record Price(BigDecimal amount, String currency) {
    }

    private final SubscriptionPriceRepository repository;
    private final PlatformAuditLogService auditLogService;
    private final String defaultCurrency;

    public SubscriptionPricing(SubscriptionPriceRepository repository, PlatformAuditLogService auditLogService,
            @Value("${app.platform.default-currency:USD}") String defaultCurrency) {
        this.repository = repository;
        this.auditLogService = auditLogService;
        this.defaultCurrency = defaultCurrency;
    }

    /** The monthly price of PRO right now. */
    @Transactional(readOnly = true)
    public Price pro() {
        return repository.findById(SubscriptionPlan.PRO)
                .map(row -> new Price(row.getMonthlyPrice(), row.getCurrency()))
                .orElseGet(() -> new Price(SubscriptionPlan.PRO.monthlyPrice, defaultCurrency));
    }

    @Transactional
    public Price setPro(UUID actorId, String actorEmail, BigDecimal monthlyPrice, String currency) {
        String code = currency.trim().toUpperCase();
        Price previous = pro();
        SubscriptionPriceRow row = repository.findById(SubscriptionPlan.PRO).orElse(null);
        if (row == null) {
            row = new SubscriptionPriceRow(SubscriptionPlan.PRO, monthlyPrice, code, Instant.now(), actorEmail);
        } else {
            row.change(monthlyPrice, code, Instant.now(), actorEmail);
        }
        repository.save(row);
        auditLogService.record(actorId, actorEmail, "SUBSCRIPTION_PRICE_SET", "SUBSCRIPTION_PLAN", null,
                previous.amount().toPlainString() + " " + previous.currency(),
                monthlyPrice.toPlainString() + " " + code, null);
        return new Price(monthlyPrice, code);
    }
}
