package com.zairo.factory.loyalty;

import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.users.User;
import com.zairo.factory.users.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * The owner's "greet this member" action: an optional personal message plus an optional gift of points. Only members
 * of this business who agreed to greetings ({@code app_user.marketing_consent}) can be greeted, at most once a day
 * each (V77's unique index), and a gift is capped so a slip of the finger can't hand out a fortune.
 */
@Service
public class LoyaltyGreetingService {

    /** Largest points gift a single greeting may carry. */
    public static final int MAX_BONUS_POINTS = 1000;
    public static final int MAX_MESSAGE_LENGTH = 500;

    private final LoyaltyGreetingRepository greetingRepository;
    private final LoyaltyLedgerService ledgerService;
    private final LoyaltyProgramRepository programRepository;
    private final UserRepository userRepository;
    private final ProviderRepository providerRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    public LoyaltyGreetingService(LoyaltyGreetingRepository greetingRepository, LoyaltyLedgerService ledgerService,
            LoyaltyProgramRepository programRepository, UserRepository userRepository,
            ProviderRepository providerRepository, ApplicationEventPublisher eventPublisher, Clock clock) {
        this.greetingRepository = greetingRepository;
        this.ledgerService = ledgerService;
        this.programRepository = programRepository;
        this.userRepository = userRepository;
        this.providerRepository = providerRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    public boolean greetedToday(UUID providerId, UUID userId) {
        return greetingRepository.existsByProviderIdAndUserIdAndGreetingDate(providerId, userId, today());
    }

    @Transactional
    public LoyaltyGreeting send(UUID providerId, UUID userId, UUID actorUserId, String message, int bonusPoints) {
        if (bonusPoints < 0 || bonusPoints > MAX_BONUS_POINTS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "bonusPoints must be between 0 and " + MAX_BONUS_POINTS);
        }
        String text = message == null || message.isBlank() ? null : message.trim();
        if (text != null && text.length() > MAX_MESSAGE_LENGTH) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "message must be at most " + MAX_MESSAGE_LENGTH + " characters");
        }
        if (ledgerService.findAccount(providerId, userId).isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Not a member of this business: " + userId);
        }
        User member = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found: " + userId));
        if (!member.isMarketingConsent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "This customer hasn't agreed to receive greetings and offers");
        }
        LocalDate today = today();
        if (greetingRepository.existsByProviderIdAndUserIdAndGreetingDate(providerId, userId, today)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This customer was already greeted today");
        }
        LoyaltyProgram program = programRepository.findByProviderId(providerId).orElse(null);
        if (bonusPoints > 0 && (program == null || !program.isEnabled())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Turn on the loyalty program to give bonus points with a greeting");
        }

        LoyaltyGreeting greeting = new LoyaltyGreeting(UUID.randomUUID(), providerId, userId, actorUserId, text,
                bonusPoints, today, Instant.now(clock));
        try {
            // Flush now so a concurrent duplicate (double tap) fails here, before any points move.
            greetingRepository.saveAndFlush(greeting);
        } catch (DataIntegrityViolationException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This customer was already greeted today");
        }
        if (bonusPoints > 0) {
            ledgerService.adjust(providerId, userId, bonusPoints, "Greeting bonus from the business", actorUserId,
                    program);
        }
        String providerName = providerRepository.findById(providerId).map(Provider::getName).orElse("");
        eventPublisher.publishEvent(new ManualGreetingSentEvent(userId, providerId, providerName, text, bonusPoints));
        return greeting;
    }

    private LocalDate today() {
        return LocalDate.now(clock.withZone(ZoneOffset.UTC));
    }
}
