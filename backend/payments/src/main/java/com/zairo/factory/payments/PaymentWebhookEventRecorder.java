package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.PaymentProviderName;
import java.time.Instant;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Split out of {@link PaymentWebhookProcessor} for one reason: the {@code
 * (provider, eventId)} unique-constraint violation that signals a duplicate
 * webhook has to happen in its <b>own</b> transaction, and that transaction
 * has to be allowed to actually roll back — catching the failure and
 * returning normally from the <em>same</em> transaction doesn't work either
 * (tried first): Hibernate marks the transaction rollback-only the moment
 * the flush hits the DB constraint, so committing it afterward — even via a
 * clean return — throws {@code UnexpectedRollbackException} right back at
 * the caller. Letting {@link DataIntegrityViolationException} propagate out
 * of this {@code REQUIRES_NEW} method instead means the failure surfaces
 * exactly once, as the exception {@link PaymentWebhookProcessor} actually
 * expects to catch, in its own (still healthy) transaction. Genuinely needs
 * a separate Spring bean either way, since {@code @Transactional} has no
 * effect on a same-class self-invocation.
 */
@Service
class PaymentWebhookEventRecorder {

    private final PaymentWebhookEventRepository webhookEventRepository;

    PaymentWebhookEventRecorder(PaymentWebhookEventRepository webhookEventRepository) {
        this.webhookEventRepository = webhookEventRepository;
    }

    /** @throws DataIntegrityViolationException if (provider, eventId) already exists — the caller's duplicate signal. */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    PaymentWebhookEvent record(PaymentProviderName provider, String eventId, String payloadHash) {
        return webhookEventRepository.saveAndFlush(new PaymentWebhookEvent(UUID.randomUUID(), provider, eventId,
                payloadHash, Instant.now()));
    }
}
