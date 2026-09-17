-- Duplicate-reversal protection for LoyaltyLedgerService#reverseEarning
-- (Phase 0 stabilization) -- extends V57's BOOKING_EARNING/REVIEW_BONUS/
-- REPEAT_VISIT_BONUS "one per booking" partial unique index to also cover
-- PAYMENT_REFUND_REVERSAL, so a retried/duplicated outbox row can never
-- claw back the same booking's points twice.
drop index uq_loyalty_transaction_booking_reference;
create unique index uq_loyalty_transaction_booking_reference on loyalty_transaction (provider_id, user_id,
    reference_type, reference_id)
    where reference_type in ('BOOKING_EARNING', 'REVIEW_BONUS', 'REPEAT_VISIT_BONUS', 'PAYMENT_REFUND_REVERSAL');
