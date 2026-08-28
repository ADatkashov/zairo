-- One thread per (customer, provider) pair — persists across multiple
-- bookings, matches how a customer would expect "message this business" to
-- work in any real marketplace app.
create table conversation (
    id uuid primary key,
    customer_id uuid not null,
    provider_id uuid not null,
    created_at timestamptz not null,
    last_message_at timestamptz not null,
    constraint uq_conversation_customer_provider unique (customer_id, provider_id)
);

create index idx_conversation_provider_id on conversation (provider_id);

create table message (
    id uuid primary key,
    conversation_id uuid not null references conversation (id),
    sender_user_id uuid not null,
    body text not null,
    created_at timestamptz not null
);

create index idx_message_conversation_id on message (conversation_id);
