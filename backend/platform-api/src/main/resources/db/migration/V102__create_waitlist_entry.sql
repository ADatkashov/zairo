-- "Tell me when a time frees up" for a fully booked business. window_start/window_end narrow it to the times the
-- customer wants (a day they picked); both null means any time. An entry is removed once the customer has been told.
create table waitlist_entry (
    id uuid primary key,
    user_id uuid not null references app_user (id) on delete cascade,
    provider_id uuid not null references provider (id) on delete cascade,
    window_start timestamptz,
    window_end timestamptz,
    created_at timestamptz not null,
    unique (user_id, provider_id)
);
create index idx_waitlist_entry_provider_id on waitlist_entry (provider_id);
