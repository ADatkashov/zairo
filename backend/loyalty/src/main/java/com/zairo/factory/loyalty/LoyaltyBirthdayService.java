package com.zairo.factory.loyalty;

import com.zairo.factory.loyalty.LoyaltyAccountRepository.BirthdayMember;
import com.zairo.factory.providers.Provider;
import com.zairo.factory.providers.ProviderRepository;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Birthday bonuses for a business's loyalty members. Only members who opted in to greetings and offers
 * ({@code app_user.marketing_consent}) and gave a birth date are ever considered -- see V75. "Member" = has a loyalty
 * account with this business, i.e. has earned or been awarded points there at least once.
 */
@Service
public class LoyaltyBirthdayService {

    private final LoyaltyAccountRepository accountRepository;
    private final LoyaltyProgramRepository programRepository;
    private final LoyaltyLedgerService ledgerService;
    private final ProviderRepository providerRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    public LoyaltyBirthdayService(LoyaltyAccountRepository accountRepository,
            LoyaltyProgramRepository programRepository, LoyaltyLedgerService ledgerService,
            ProviderRepository providerRepository, ApplicationEventPublisher eventPublisher, Clock clock) {
        this.accountRepository = accountRepository;
        this.programRepository = programRepository;
        this.ledgerService = ledgerService;
        this.providerRepository = providerRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    /** One opted-in member whose birthday is within the requested window. */
    public record UpcomingBirthday(UUID userId, String displayName, LocalDate date, int daysUntil, boolean bonusAwarded) {
    }

    /**
     * Opted-in members of this business whose birthday is {@code today}. The sweep then calls {@link #awardOne} for
     * each through the Spring proxy (not from inside this class), so every award gets its own transaction and the
     * {@link BirthdayBonusAwardedEvent} fires after that award's commit.
     */
    public List<UUID> birthdayMemberIds(LoyaltyProgram program, LocalDate today) {
        if (!program.isEnabled() || program.getBirthdayBonusPoints() <= 0) {
            return List.of();
        }
        int[] days = BirthdayCalendar.dayRangeForToday(today);
        return accountRepository.findBirthdayMembers(program.getProviderId(), today.getMonthValue(), days[0], days[1])
                .stream().map(BirthdayMember::getUserId).toList();
    }

    /**
     * Awards one member's bonus for {@code year}; false if it was already awarded (or capped to nothing). Must be
     * called from outside this class so {@code @Transactional} applies and the event rides this award's commit.
     */
    @Transactional
    public boolean awardOne(LoyaltyProgram program, UUID userId, int year) {
        boolean awarded = ledgerService.earn(program.getProviderId(), userId, program.getBirthdayBonusPoints(),
                LoyaltyTransactionType.BONUS, LoyaltyReferenceType.BIRTHDAY_BONUS, referenceId(userId, year), null,
                "Birthday bonus", program).isPresent();
        if (awarded) {
            String providerName = providerRepository.findById(program.getProviderId()).map(Provider::getName)
                    .orElse("");
            eventPublisher.publishEvent(new BirthdayBonusAwardedEvent(userId, program.getProviderId(), providerName,
                    program.getBirthdayBonusPoints()));
        }
        return awarded;
    }

    /** Opted-in members whose birthday is within the next {@code days} days (today included), soonest first. */
    @Transactional(readOnly = true)
    public List<UpcomingBirthday> upcoming(UUID providerId, int days) {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        return accountRepository.findAllBirthdayMembers(providerId).stream().map(member -> {
            LocalDate next = BirthdayCalendar.nextBirthday(member.getBirthDate(), today);
            int daysUntil = (int) java.time.temporal.ChronoUnit.DAYS.between(today, next);
            boolean awarded = daysUntil == 0 && ledgerService.hasEarning(providerId, member.getUserId(),
                    LoyaltyReferenceType.BIRTHDAY_BONUS, referenceId(member.getUserId(), today.getYear()));
            return new UpcomingBirthday(member.getUserId(), member.getDisplayName(), next, daysUntil, awarded);
        }).filter(b -> b.daysUntil() <= days).sorted(Comparator.comparingInt(UpcomingBirthday::daysUntil)
                .thenComparing(UpcomingBirthday::displayName, Comparator.nullsLast(String::compareToIgnoreCase)))
                .toList();
    }

    /** Programs the daily sweep must visit. */
    public List<LoyaltyProgram> programsGrantingBirthdayBonus() {
        return programRepository.findByEnabledTrueAndBirthdayBonusPointsGreaterThan(0);
    }

    /** Deterministic per (member, year) -- the unique index in V76 turns this into a hard once-a-year guarantee. */
    static UUID referenceId(UUID userId, int year) {
        return UUID.nameUUIDFromBytes(("birthday:" + year + ":" + userId).getBytes(StandardCharsets.UTF_8));
    }
}
