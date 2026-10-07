-- The owner asked a customer to decide what happens to an appointment whose worker can't make it (the customer
-- chose a specific person, so the business doesn't swap them silently).
create table worker_change_request (
    booking_id uuid primary key references booking (id),
    provider_id uuid not null references provider (id),
    reason varchar(32) not null,
    status varchar(16) not null,
    resolution varchar(24),
    created_at timestamptz not null,
    resolved_at timestamptz
);

create index idx_worker_change_request_provider_id on worker_change_request (provider_id, status);
