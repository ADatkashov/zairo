package com.zairo.factory.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "message")
public class Message {

    @Id
    private UUID id;

    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    /** Either the conversation's customerId or its provider's ownerUserId — see MessagingService.requireParticipant. */
    @Column(name = "sender_user_id", nullable = false)
    private UUID senderUserId;

    @Column(nullable = false)
    private String body;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Message() {
    }

    public Message(UUID id, UUID conversationId, UUID senderUserId, String body, Instant createdAt) {
        this.id = id;
        this.conversationId = conversationId;
        this.senderUserId = senderUserId;
        this.body = body;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getConversationId() {
        return conversationId;
    }

    public UUID getSenderUserId() {
        return senderUserId;
    }

    public String getBody() {
        return body;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
