package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.paymentprovider.PaymentProviderName;
import java.time.Clock;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * A customer's saved cards: what is stored, shown and removed. Only the last
 * four digits and the brand are ever kept. Charging a saved card is {@code
 * PaymentProvider.chargeRecurring}, called from {@link PaymentsService}.
 *
 * <p>Removing a card is <b>local</b>: the provider-side profile is not revoked
 * (Freedom Pay's profile-deletion request is not confirmed — ADR-0006); without
 * the stored profile id this platform can no longer charge it.
 */
@Service
public class SavedCardService {

    private final SavedCardRepository cardRepository;
    private final SavedCardPreferenceRepository preferenceRepository;
    private final PaymentProvider paymentProvider;
    private final PaymentProviderName providerName;
    private final Clock clock;

    public SavedCardService(SavedCardRepository cardRepository, SavedCardPreferenceRepository preferenceRepository,
            PaymentProvider paymentProvider, @Value("${payment.provider:mock}") String providerName, Clock clock) {
        this.cardRepository = cardRepository;
        this.preferenceRepository = preferenceRepository;
        this.paymentProvider = paymentProvider;
        this.providerName = PaymentProviderName.valueOf(providerName.toUpperCase());
        this.clock = clock;
    }

    public List<SavedCard> list(UUID userId) {
        return cardRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    /** The card must be the caller's own — anyone else's id is simply "not found". */
    public SavedCard requireOwn(UUID cardId, UUID userId) {
        return cardRepository.findByIdAndUserId(cardId, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found: " + cardId));
    }

    /** Whether a stored card can really be charged without the customer going to the provider's page. */
    public boolean canPayWithSavedCard() {
        return paymentProvider.supportsRecurringCharge();
    }

    public boolean saveOnNextPayment(UUID userId) {
        return preferenceRepository.findById(userId).map(SavedCardPreference::isSaveOnNextPayment).orElse(false);
    }

    @Transactional
    public void setSaveOnNextPayment(UUID userId, boolean value) {
        var now = clock.instant();
        SavedCardPreference preference = preferenceRepository.findById(userId).orElse(null);
        if (preference == null) {
            preferenceRepository.save(new SavedCardPreference(userId, value, now));
        } else {
            preference.set(value, now);
            preferenceRepository.save(preference);
        }
    }

    /** Remembers the card a successful payment produced; the same profile is stored once. A null profile changes nothing. */
    @Transactional
    public void save(UUID userId, String recurringProfileId, String cardPanOrLast4, String cardBrand) {
        if (recurringProfileId == null || recurringProfileId.isBlank()) {
            return;
        }
        if (cardRepository.findByUserIdAndRecurringProfileId(userId, recurringProfileId).isPresent()) {
            return;
        }
        cardRepository.save(new SavedCard(UUID.randomUUID(), userId, providerName, recurringProfileId,
                last4(cardPanOrLast4), brand(cardBrand), clock.instant()));
    }

    @Transactional
    public void remove(UUID cardId, UUID userId) {
        cardRepository.delete(requireOwn(cardId, userId));
    }

    /** Keeps only the last four digits of whatever the provider reported (a masked PAN like {@code 4242 42** **** 4242}). */
    static String last4(String panOrLast4) {
        if (panOrLast4 == null) {
            return null;
        }
        String digits = panOrLast4.replaceAll("\\D", "");
        return digits.length() < 4 ? null : digits.substring(digits.length() - 4);
    }

    static String brand(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String cleaned = raw.trim().toUpperCase().replaceAll("[^A-Z ]", "");
        return cleaned.isBlank() ? null : cleaned.substring(0, Math.min(cleaned.length(), 20));
    }
}
