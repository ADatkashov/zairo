package com.zairo.factory.messaging;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.Booking;
import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.messaging.MessagingDtos.ConversationResponse;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderOwnership;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
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
    private final BookingRepository bookingRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final UserRepository userRepository;

    public MessagingService(ConversationRepository conversationRepository, MessageRepository messageRepository,
            ProviderRepository providerRepository, ProviderOwnership providerOwnership,
            BookingRepository bookingRepository, AvailabilitySlotRepository availabilitySlotRepository,
            UserRepository userRepository) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.providerRepository = providerRepository;
        this.providerOwnership = providerOwnership;
        this.bookingRepository = bookingRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.userRepository = userRepository;
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
        return appendMessage(conversation, customerId, body, null);
    }

    /**
     * Same as {@link #sendAsCustomer}, but tags the message with the booking it's
     * about (e.g. sent from that booking's detail screen) — the provider is
     * resolved from the booking itself (booking -> availability slot -> provider,
     * same reasoning as {@code reviews.ReviewService}), not trusted from the
     * caller, and the caller must own the booking.
     */
    @Transactional
    public Message sendAsCustomerForBooking(UUID bookingId, UUID customerId, String body) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found: "
                        + bookingId));
        if (!booking.getUserId().equals(customerId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this booking: " + bookingId);
        }
        AvailabilitySlot slot = availabilitySlotRepository.findById(booking.getAvailabilitySlotId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Availability slot not found: "
                        + booking.getAvailabilitySlotId()));
        UUID providerId = slot.getProviderId();
        Conversation conversation = conversationRepository.findByCustomerIdAndProviderId(customerId, providerId)
                .orElseGet(() -> conversationRepository.save(new Conversation(UUID.randomUUID(), customerId,
                        providerId, Instant.now())));
        return appendMessage(conversation, customerId, body, bookingId);
    }

    /** Either side may reply once a thread exists — see {@link #requireParticipant}. */
    @Transactional
    public Message reply(UUID conversationId, UUID callerId, String body) {
        Conversation conversation = findConversation(conversationId);
        requireParticipant(conversation, callerId);
        return appendMessage(conversation, callerId, body, null);
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
    public List<ConversationResponse> conversationsForCustomer(UUID customerId) {
        return toResponses(conversationRepository.findByCustomerIdOrderByLastMessageAtDesc(customerId));
    }

    /** The business's inbox — only its own owner may see it. */
    public List<ConversationResponse> conversationsForProvider(UUID providerId, UUID callerId) {
        providerOwnership.requireOwner(providerId, callerId);
        return toResponses(conversationRepository.findByProviderIdOrderByLastMessageAtDesc(providerId));
    }

    /**
     * Batch-resolves each conversation's customer display name and provider name —
     * there's no client-usable "get user by id" (it's admin-only, see
     * users.UserController), so the name has to be embedded here, same reasoning as
     * provider-insights' CustomerSummary. One query per id set, not per conversation.
     */
    private List<ConversationResponse> toResponses(List<Conversation> conversations) {
        if (conversations.isEmpty()) {
            return List.of();
        }
        Map<UUID, User> usersById = userRepository
                .findAllById(conversations.stream().map(Conversation::getCustomerId).distinct().toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        Map<UUID, Provider> providersById = providerRepository
                .findAllById(conversations.stream().map(Conversation::getProviderId).distinct().toList()).stream()
                .collect(Collectors.toMap(Provider::getId, Function.identity()));
        return conversations.stream().map(conversation -> {
            User customer = usersById.get(conversation.getCustomerId());
            Provider provider = providersById.get(conversation.getProviderId());
            return ConversationResponse.from(conversation, customer == null ? null : customer.getDisplayName(),
                    provider == null ? null : provider.getName());
        }).toList();
    }

    private Message appendMessage(Conversation conversation, UUID senderUserId, String body, UUID bookingId) {
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
        return messageRepository.save(new Message(UUID.randomUUID(), conversation.getId(), senderUserId, body,
                bookingId, now));
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
