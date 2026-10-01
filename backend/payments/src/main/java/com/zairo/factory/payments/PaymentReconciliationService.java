package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.PaymentProvider;
import com.zairo.factory.paymentprovider.PaymentProvider.InitiationStatus;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Compares ZAIRO's own {@code Payment.status} against what the provider
 * itself reports, on demand — Phase 16's "ZAIRO DB vs Freedom Pay" check.
 * Uses {@link PaymentProvider#getPaymentStatus}, a port method that already
 * existed (see its own doc comment: "a reconciliation fallback... not yet
 * called anywhere") but had no caller until now.
 *
 * <p><b>Never silently corrects a discrepancy</b> — the task's own explicit
 * requirement ("нельзя молча исправлять финансовые данные"). A mismatch is
 * reported as {@link Outcome#DISCREPANCY} for a human (platform admin) to
 * investigate; nothing here writes to {@code Payment} at all.
 */
@Service
public class PaymentReconciliationService {

    private static final Logger log = LoggerFactory.getLogger(PaymentReconciliationService.class);

    private final PaymentRepository paymentRepository;
    private final PaymentProvider paymentProvider;

    PaymentReconciliationService(PaymentRepository paymentRepository, PaymentProvider paymentProvider) {
        this.paymentRepository = paymentRepository;
        this.paymentProvider = paymentProvider;
    }

    public enum Outcome {
        /** ZAIRO's own status and the provider's agree (or the payment has no provider reference yet — nothing to compare). */
        MATCH,
        /** They disagree — RECONCILIATION_REQUIRED, needs a human, not an automatic fix. */
        DISCREPANCY
    }

    public record Result(Outcome outcome, PaymentStatus localStatus, InitiationStatus providerStatus,
            String providerReference) {
    }

    public Result reconcile(UUID paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Payment not found: "
                        + paymentId));

        if (payment.getProviderReference() == null) {
            // Never actually reached the provider (still CREATED after a
            // network error, or genuinely never charged) — nothing to
            // compare against.
            return new Result(Outcome.MATCH, payment.getStatus(), null, null);
        }

        PaymentProvider.PaymentStatusResult providerResult = paymentProvider.getPaymentStatus(payment.getId(),
                payment.getProviderReference());

        boolean matches = statusesAgree(payment.getStatus(), providerResult.status());
        if (!matches) {
            log.warn("RECONCILIATION_REQUIRED: payment {} is {} locally but {} at the provider", paymentId,
                    payment.getStatus(), providerResult.status());
        }
        return new Result(matches ? Outcome.MATCH : Outcome.DISCREPANCY, payment.getStatus(), providerResult.status(),
                providerResult.providerReference());
    }

    /**
     * {@code SUCCEEDED}/{@code REFUNDED}/{@code REFUND_FAILED} all
     * correspond to the provider having actually captured the charge —
     * {@link PaymentProvider.PaymentStatusResult} doesn't carry a separate
     * refunded state (see its own doc comment: this port method predates
     * refund tracking), so any of those three still agreeing with the
     * provider's SUCCEEDED is a match, not a false discrepancy.
     *
     * <p><b>{@code PENDING} matches only provider {@code PENDING}</b> —
     * deliberately not lenient about {@code SUCCEEDED}/{@code FAILED} here:
     * a payment stuck locally at PENDING while the provider already
     * resolved it one way or the other is exactly the "webhook never
     * arrived" scenario this whole service exists to catch, not a case to
     * wave through as a match.
     */
    private static boolean statusesAgree(PaymentStatus local, InitiationStatus provider) {
        return switch (local) {
            case SUCCEEDED, REFUNDED, REFUND_FAILED, REFUND_PENDING -> provider == InitiationStatus.SUCCEEDED;
            case FAILED -> provider == InitiationStatus.FAILED;
            case PENDING -> provider == InitiationStatus.PENDING;
            case CREATED -> true;
        };
    }
}
