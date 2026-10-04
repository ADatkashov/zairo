package com.zairo.factory.depositpolicy;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Manage payment settings (deposit policy) for providers.
 * Settings apply to new bookings created after being set.
 */
@Service
public class PaymentSettingsService {

    private final PaymentSettingsRepository paymentSettingsRepository;

    public PaymentSettingsService(PaymentSettingsRepository paymentSettingsRepository) {
        this.paymentSettingsRepository = paymentSettingsRepository;
    }

    @Transactional(readOnly = true)
    public PaymentSettings getOrCreateSettings(UUID providerId) {
        return paymentSettingsRepository.findByProviderId(providerId)
                .orElseGet(() -> createDefaultSettings(providerId));
    }

    /** Read-only lookup that never creates the default row (safe for public reads). */
    @Transactional(readOnly = true)
    public java.util.Optional<PaymentSettings> findSettings(UUID providerId) {
        return paymentSettingsRepository.findByProviderId(providerId);
    }

    private PaymentSettings createDefaultSettings(UUID providerId) {
        PaymentSettings settings = new PaymentSettings(UUID.randomUUID(), providerId, Instant.now());
        return paymentSettingsRepository.save(settings);
    }

    @Transactional
    public PaymentSettings updateSettings(UUID providerId, DepositType depositType,
            DepositValueType depositValueType, BigDecimal depositValue) {
        PaymentSettings settings = getOrCreateSettings(providerId);

        validateSettings(depositType, depositValueType, depositValue);
        settings.applySettings(depositType, depositValueType, depositValue, Instant.now());

        return paymentSettingsRepository.save(settings);
    }

    private void validateSettings(DepositType depositType, DepositValueType depositValueType,
            BigDecimal depositValue) {
        if (depositType == DepositType.DEPOSIT) {
            if (depositValueType == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "depositValueType is required when depositType is DEPOSIT");
            }
            if (depositValue == null || depositValue.compareTo(BigDecimal.ZERO) <= 0) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "depositValue must be positive when depositType is DEPOSIT");
            }
            if (depositValueType == DepositValueType.PERCENTAGE) {
                if (depositValue.compareTo(BigDecimal.ZERO) < 0 || depositValue.compareTo(new BigDecimal(100)) > 0) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "depositValue must be between 0 and 100 for PERCENTAGE type");
                }
            }
        } else {
            // For NO_PAYMENT and FULL_PAYMENT, depositValueType and depositValue should be null
            if (depositValueType != null || depositValue != null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "depositValueType and depositValue should be null when depositType is " + depositType);
            }
        }
    }
}
