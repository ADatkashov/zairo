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
            @Schema(description = "Set only if this message was sent from a specific booking's detail screen.",
                    example = "550e8400-e29b-41d4-a716-446655440000") UUID bookingId,
            Instant createdAt) {
        static MessageResponse from(Message message) {
            return new MessageResponse(message.getId(), message.getConversationId(), message.getSenderUserId(),
                    message.getBody(), message.getBookingId(), message.getCreatedAt());
        }
    }

    public record ConversationResponse(
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID id,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID customerId,
            @Schema(description = "The customer's display name — resolved server-side, same reasoning as "
                    + "provider-insights' CustomerSummary (there's no client-usable \"get user by id\", it's "
                    + "admin-only).", example = "Aigerim Bekova") String customerDisplayName,
            @Schema(example = "550e8400-e29b-41d4-a716-446655440000") UUID providerId,
            @Schema(example = "Aigerim Beauty Salon") String providerName,
            Instant createdAt,
            Instant lastMessageAt) {
        static ConversationResponse from(Conversation conversation, String customerDisplayName, String providerName) {
            return new ConversationResponse(conversation.getId(), conversation.getCustomerId(), customerDisplayName,
                    conversation.getProviderId(), providerName, conversation.getCreatedAt(),
                    conversation.getLastMessageAt());
        }
    }
}
