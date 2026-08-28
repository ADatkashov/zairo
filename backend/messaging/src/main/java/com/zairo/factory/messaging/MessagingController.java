package com.zairo.factory.messaging;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.messaging.MessagingDtos.ConversationResponse;
import com.zairo.factory.messaging.MessagingDtos.MessageResponse;
import com.zairo.factory.messaging.MessagingDtos.SendMessageRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Messaging")
public class MessagingController {

    private final MessagingService messagingService;

    public MessagingController(MessagingService messagingService) {
        this.messagingService = messagingService;
    }

    @Operation(summary = "Message a business", description = """
            Starts the conversation on first contact, or continues the existing one — the caller \
            (always a customer here) never needs to know a conversationId upfront.""")
    @ApiResponse(responseCode = "201", description = "Message sent")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "404", ref = "NotFound", description = "The provider doesn't exist.")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/providers/{providerId}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse sendToProvider(@Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            @Valid @RequestBody SendMessageRequest request, HttpServletRequest httpRequest) {
        UUID customerId = CurrentUser.requireUserId(httpRequest);
        return MessageResponse.from(messagingService.sendAsCustomer(customerId, providerId, request.body()));
    }

    @Operation(summary = "Read my thread with a business",
            description = "Empty list if the caller has never messaged this provider — not a 404.")
    @ApiResponse(responseCode = "200", description = "Messages, oldest first")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/messages")
    public List<MessageResponse> getThreadWithProvider(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        UUID customerId = CurrentUser.requireUserId(httpRequest);
        return messagingService.getMessagesForCustomerAndProvider(customerId, providerId).stream()
                .map(MessageResponse::from).toList();
    }

    @Operation(summary = "A business's own message inbox", description = "Only the provider's own owner may read it.")
    @ApiResponse(responseCode = "200", description = "Conversations, most recently active first")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller isn't a participant in this conversation.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/providers/{providerId}/conversations")
    public List<ConversationResponse> providerInbox(
            @Parameter(description = "The provider's id.") @PathVariable UUID providerId,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        return messagingService.conversationsForProvider(providerId, callerId).stream()
                .map(ConversationResponse::from).toList();
    }

    @Operation(summary = "My own message inbox (as a customer)")
    @ApiResponse(responseCode = "200", description = "Conversations, most recently active first")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/conversations/mine")
    public List<ConversationResponse> myInbox(HttpServletRequest httpRequest) {
        UUID customerId = CurrentUser.requireUserId(httpRequest);
        return messagingService.conversationsForCustomer(customerId).stream().map(ConversationResponse::from)
                .toList();
    }

    @Operation(summary = "Reply in an existing conversation",
            description = "Works for either side — the caller must be the conversation's customer or that "
                    + "provider's owner.")
    @ApiResponse(responseCode = "201", description = "Message sent")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller isn't a participant in this conversation.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/api/v1/conversations/{conversationId}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse reply(@Parameter(description = "The conversation's id.") @PathVariable UUID conversationId,
            @Valid @RequestBody SendMessageRequest request, HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        return MessageResponse.from(messagingService.reply(conversationId, callerId, request.body()));
    }

    @Operation(summary = "Read a conversation by id",
            description = "The caller must be the conversation's customer or that provider's owner.")
    @ApiResponse(responseCode = "200", description = "Messages, oldest first")
    @ApiResponse(responseCode = "401", ref = "Unauthorized")
    @ApiResponse(responseCode = "403", description = "The caller isn't a participant in this conversation.",
            content = @Content(mediaType = "application/json", schema = @Schema(ref = "#/components/schemas/ApiError")))
    @ApiResponse(responseCode = "404", ref = "NotFound")
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/api/v1/conversations/{conversationId}/messages")
    public List<MessageResponse> getConversation(
            @Parameter(description = "The conversation's id.") @PathVariable UUID conversationId,
            HttpServletRequest httpRequest) {
        UUID callerId = CurrentUser.requireUserId(httpRequest);
        return messagingService.getMessages(conversationId, callerId).stream().map(MessageResponse::from).toList();
    }
}
