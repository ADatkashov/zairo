-- Birthday bonus: points a business grants a loyalty member on their birthday.
-- 0 = the business doesn't give one (default, so existing programs are unchanged).
alter table loyalty_program add column birthday_bonus_points integer not null default 0;
alter table loyalty_program add constraint chk_loyalty_program_birthday_bonus_non_negative
    check (birthday_bonus_points >= 0);

-- At most one birthday bonus per member per year. The sweep derives a
-- deterministic reference_id from (user, year), so a re-run, a second app
-- instance or a retry can never double-award - enforced by the database, not
-- just by the application-level exists check in LoyaltyLedgerService#earn.
create unique index uq_loyalty_transaction_birthday_bonus on loyalty_transaction (provider_id, user_id, reference_id)
    where reference_type = 'BIRTHDAY_BONUS';
