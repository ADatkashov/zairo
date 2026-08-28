-- One row per distinct provider webhook delivery, keyed on (provider, event_id)
-- rather than a single global unique event id — Freedom Pay's Result-notify
-- webhook has no per-delivery id of its own; pg_payment_id is what repeats
-- across up to 4 retries of the SAME notification (see ADR-0006's Webhook
-- Architecture / FreedomPayWebhookVerifier's doc comment). The unique
-- constraint is what makes a duplicate delivery a safe, cheap no-op instead
-- of a second business-effect application.
create table payment_webhook_event (
    id uuid primary key,
    provider varchar(32) not null,
    event_id varchar(255) not null,
    payment_id uuid,
    received_at timestamptz not null,
    processed_at timestamptz,
    status varchar(32) not null,
    failure_reason text,
    payload_hash varchar(64) not null,
    constraint uq_payment_webhook_event_provider_event_id unique (provider, event_id)
);

create index idx_payment_webhook_event_payment_id on payment_webhook_event (payment_id);
