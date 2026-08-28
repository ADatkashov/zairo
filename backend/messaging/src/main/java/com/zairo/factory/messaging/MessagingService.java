package com.zairo.factory.messaging;

import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.providers.ProviderRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class MessagingService {

    private static final int MAX_BODY_LENGTH = 2000;

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final ProviderRepository providerRepository;
    private final ProviderOwnership providerOwnership;

    public MessagingService(ConversationRepository conversationRepository, MessageRepository messageRepository,
            ProviderRepository providerRepository, ProviderOwnership providerOwnership) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.providerRepository = providerRepository;
        this.providerOwnership = providerOwnership;
    }

    /** Starts the (customer, provider) thread on first contact, or continues the existing one — idempotent either way. */
    @Transactional
    public Message sendAsCustomer(UUID customerId, UUID providerId, String body) {
        if (!providerRepository.existsById(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Provider not found: " + providerId);
        }
        Conversation conversation = conversationRepository.findByCustomerIdAndProviderId(customerId, providerId)
                .orElseGet(() -> conversationRepository.save(new Conversation(UUID.randomUUID(), customerId,
                        providerId, Instant.now())));
        return appendMessage(conversation, customerId, body);
    }

    /** Either side may reply once a thread exists — see {@link #requireParticipant}. */
    @Transactional
    public Message reply(UUID conversationId, UUID callerId, String body) {
        Conversation conversation = findConversation(conversationId);
        requireParticipant(conversation, callerId);
        return appendMessage(conversation, callerId, body);
    }

    public List<Message> getMessages(UUID conversationId, UUID callerId) {
        Conversation conversation = findConversation(conversationId);
        requireParticipant(conversation, callerId);
        return messageRepository.findByConversationIdOrderByCreatedAtAsc(conversationId);
    }

    /** The customer's view of their own thread with one provider, straight from the providerId — no conversation lookup needed first. Empty if they've never messaged this provider. */
    public List<Message> getMessagesForCustomerAndProvider(UUID customerId, UUID providerId) {
        return conversationRepository.findByCustomerIdAndProviderId(customerId, providerId)
                .map(conversation -> messageRepository.findByConversationIdOrderByCreatedAtAsc(conversation.getId()))
                .orElseGet(List::of);
    }

    /** The customer's own inbox — every business they've messaged, most recently active first. */
    public List<Conversation> conversationsForCustomer(UUID customerId) {
        return conversationRepository.findByCustomerIdOrderByLastMessageAtDesc(customerId);
    }

    /** The business's inbox — only its own owner may see it. */
    public List<Conversation> conversationsForProvider(UUID providerId, UUID callerId) {
        providerOwnership.requireOwner(providerId, callerId);
        return conversationRepository.findByProviderIdOrderByLastMessageAtDesc(providerId);
    }

    private Message appendMessage(Conversation conversation, UUID senderUserId, String body) {
        if (body == null || body.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Message body must not be blank");
        }
        if (body.length() > MAX_BODY_LENGTH) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Message body must not exceed " + MAX_BODY_LENGTH + " characters");
        }
        Instant now = Instant.now();
        conversation.touch(now);
        conversationRepository.save(conversation);
        return messageRepository.save(new Message(UUID.randomUUID(), conversation.getId(), senderUserId, body, now));
    }

    private Conversation findConversation(UUID conversationId) {
        return conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Conversation not found: "
                        + conversationId));
    }

    /** The customer this conversation belongs to, or (only) that provider's owner — nobody else. */
    private void requireParticipant(Conversation conversation, UUID callerId) {
        if (conversation.getCustomerId().equals(callerId)) {
            return;
        }
        providerOwnership.requireOwner(conversation.getProviderId(), callerId);
    }
}
