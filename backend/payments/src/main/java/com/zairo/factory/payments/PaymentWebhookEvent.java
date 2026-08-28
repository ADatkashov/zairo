package com.zairo.factory.payments;

import com.zairo.factory.paymentprovider.PaymentProviderName;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * One row per distinct provider webhook delivery — the durable, queryable
 * record {@code PaymentWebhookProcessor} uses for both deduplication (the
 * {@code (provider, eventId)} unique constraint — see V32's migration
 * comment) and observability (what did we receive, when, and what did we do
 * with it). {@code eventId} is Freedom Pay's {@code pg_payment_id} — see
 * {@code FreedomPayWebhookVerifier}'s doc comment for why that's the closest
 * thing to a dedup key this provider's API actually offers.
 */
@Entity
@Table(name = "payment_webhook_event")
public class PaymentWebhookEvent {

    @Id
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentProviderName provider;

    @Column(name = "event_id", nullable = false)
    private String eventId;

    /** Resolved once the payment this event refers to is looked up — null if that lookup fails. */
    @Column(name = "payment_id")
    private UUID paymentId;

    @Column(name = "received_at", nullable = false, updatable = false)
    private Instant receivedAt;

    @Column(name = "processed_at")
    private Instant processedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private PaymentWebhookEventStatus status;

    @Column(name = "failure_reason")
    private String failureReason;

    /**
     * SHA-256 hex of the raw payload — audit/debugging only (e.g. "did a
     * retried delivery actually send identical fields"), never compared for
     * dedup logic itself (that's {@code eventId}'s job).
     */
    @Column(name = "payload_hash", nullable = false)
    private String payloadHash;

    protected PaymentWebhookEvent() {
    }

    public PaymentWebhookEvent(UUID id, PaymentProviderName provider, String eventId, String payloadHash,
            Instant receivedAt) {
        this.id = id;
        this.provider = provider;
        this.eventId = eventId;
        this.payloadHash = payloadHash;
        this.receivedAt = receivedAt;
        this.status = PaymentWebhookEventStatus.RECEIVED;
    }

    public UUID getId() {
        return id;
    }

    public PaymentProviderName getProvider() {
        return provider;
    }

    public String getEventId() {
        return eventId;
    }

    public UUID getPaymentId() {
        return paymentId;
    }

    public PaymentWebhookEventStatus getStatus() {
        return status;
    }

    public String getFailureReason() {
        return failureReason;
    }

    void assignPayment(UUID paymentId) {
        this.paymentId = paymentId;
    }

    void markProcessed(Instant now) {
        this.status = PaymentWebhookEventStatus.PROCESSED;
        this.processedAt = now;
    }

    void markFailed(String reason, Instant now) {
        this.status = PaymentWebhookEventStatus.FAILED;
        this.failureReason = reason;
        this.processedAt = now;
    }
}
