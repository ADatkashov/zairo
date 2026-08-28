package com.zairo.factory.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** One thread per (customer, provider) pair — see package-info. */
@Entity
@Table(name = "conversation")
public class Conversation {

    @Id
    private UUID id;

    @Column(name = "customer_id", nullable = false)
    private UUID customerId;

    @Column(name = "provider_id", nullable = false)
    private UUID providerId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "last_message_at", nullable = false)
    private Instant lastMessageAt;

    protected Conversation() {
    }

    public Conversation(UUID id, UUID customerId, UUID providerId, Instant createdAt) {
        this.id = id;
        this.customerId = customerId;
        this.providerId = providerId;
        this.createdAt = createdAt;
        this.lastMessageAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCustomerId() {
        return customerId;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getLastMessageAt() {
        return lastMessageAt;
    }

    void touch(Instant now) {
        this.lastMessageAt = now;
    }
}
