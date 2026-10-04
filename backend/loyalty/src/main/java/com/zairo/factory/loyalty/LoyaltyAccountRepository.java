package com.zairo.factory.loyalty;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LoyaltyAccountRepository extends JpaRepository<LoyaltyAccount, UUID> {

    Optional<LoyaltyAccount> findByProviderIdAndUserId(UUID providerId, UUID userId);

    /**
     * Atomic upsert-the-row-if-missing, so {@link LoyaltyLedgerService}
     * never has to reason about a create-then-lock race between two
     * concurrent first-ever earn/consume calls for the same account --
     * the database's own unique constraint on ({@code provider_id, user_id})
     * resolves it in one statement instead of a catch-and-retry dance
     * around a persistence-context exception.
     */
    @Modifying
    @Query(value = "insert into loyalty_account "
            + "(id, provider_id, user_id, points_balance, lifetime_earned, lifetime_redeemed, lifetime_expired, "
            + "completed_visits, created_at, version) "
            + "values (:id, :providerId, :userId, 0, 0, 0, 0, 0, :now, 0) "
            + "on conflict (provider_id, user_id) do nothing", nativeQuery = true)
    void insertIfAbsent(@Param("id") UUID id, @Param("providerId") UUID providerId, @Param("userId") UUID userId,
            @Param("now") Instant now);

    List<LoyaltyAccount> findByUserId(UUID userId);

    Page<LoyaltyAccount> findByProviderId(UUID providerId, Pageable pageable);

    /**
     * Takes a row-level write lock for the whole redeem-or-expire
     * operation -- see LoyaltyLedgerService#consume and this module's own
     * package-info ("Concurrency-safe redemption"). Two concurrent
     * requests against the same account serialize instead of both reading
     * a stale balance and racing to a negative one.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from LoyaltyAccount a where a.providerId = :providerId and a.userId = :userId")
    Optional<LoyaltyAccount> lockByProviderIdAndUserId(@Param("providerId") UUID providerId,
            @Param("userId") UUID userId);

    /** A loyalty member who opted in to greetings and has a birth date on file -- see V75. */
    interface BirthdayMember {
        UUID getUserId();

        String getDisplayName();

        java.time.LocalDate getBirthDate();
    }

    /**
     * Members of this business whose birthday falls in {@code month} on a day-of-month in
     * [{@code dayFrom}, {@code dayTo}] -- opted-in members only (users.marketing_consent). The range is wider than one
     * day only for the 29-Feb-in-a-non-leap-year case, see {@link BirthdayCalendar#dayRangeForToday}.
     */
    @Query(value = "select u.id as userId, u.display_name as displayName, u.birth_date as birthDate "
            + "from loyalty_account a join app_user u on u.id = a.user_id "
            + "where a.provider_id = :providerId and u.marketing_consent = true and u.birth_date is not null "
            + "and extract(month from u.birth_date) = :month "
            + "and extract(day from u.birth_date) between :dayFrom and :dayTo", nativeQuery = true)
    List<BirthdayMember> findBirthdayMembers(@Param("providerId") UUID providerId, @Param("month") int month,
            @Param("dayFrom") int dayFrom, @Param("dayTo") int dayTo);

    /** Every opted-in member with a birth date -- the pool the "upcoming birthdays" list filters in memory. */
    @Query(value = "select u.id as userId, u.display_name as displayName, u.birth_date as birthDate "
            + "from loyalty_account a join app_user u on u.id = a.user_id "
            + "where a.provider_id = :providerId and u.marketing_consent = true and u.birth_date is not null",
            nativeQuery = true)
    List<BirthdayMember> findAllBirthdayMembers(@Param("providerId") UUID providerId);

    long countByProviderId(UUID providerId);

    @Query("select count(a) from LoyaltyAccount a where a.providerId = :providerId and a.lastActivityAt >= :since")
    long countActiveSince(@Param("providerId") UUID providerId, @Param("since") Instant since);

    @Query("select coalesce(sum(a.pointsBalance), 0) from LoyaltyAccount a where a.providerId = :providerId")
    long sumOutstandingBalance(@Param("providerId") UUID providerId);

    @Query("select coalesce(sum(a.lifetimeEarned), 0) from LoyaltyAccount a where a.providerId = :providerId")
    long sumLifetimeEarned(@Param("providerId") UUID providerId);

    @Query("select coalesce(sum(a.lifetimeRedeemed), 0) from LoyaltyAccount a where a.providerId = :providerId")
    long sumLifetimeRedeemed(@Param("providerId") UUID providerId);
}
