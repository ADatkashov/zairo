package com.zairo.factory.messaging;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class MessagingDtos {

    private MessagingDtos() {
    }

    public record SendMessageRequest(
            @NotBlank @Size(max = 2000) @Schema(example = "Hi, is this Saturday slot still open?") String body) {
    }

    public record MessageResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID conversationId,
            @Schema(description = "Either the conversation's customer, or the business's owner.")
            UUID senderUserId,
            String body,
            Instant createdAt) {
        static MessageResponse from(Message message) {
            return new MessageResponse(message.getId(), message.getConversationId(), message.getSenderUserId(),
                    message.getBody(), message.getCreatedAt());
        }
    }

    public record ConversationResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID customerId,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            Instant createdAt,
            Instant lastMessageAt) {
        static ConversationResponse from(Conversation conversation) {
            return new ConversationResponse(conversation.getId(), conversation.getCustomerId(),
                    conversation.getProviderId(), conversation.getCreatedAt(), conversation.getLastMessageAt());
        }
    }
}
