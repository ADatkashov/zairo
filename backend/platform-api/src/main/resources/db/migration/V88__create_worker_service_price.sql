-- Per-worker price of a service, used only when the business turned on "different prices per master".
-- No row = the service's own price. The price a customer agreed to is copied into the booking, so later
-- edits here never change existing bookings.
create table worker_service_price (
    id uuid primary key,
    provider_id uuid not null references provider (id),
    worker_id uuid not null,
    service_id uuid not null references service (id),
    price numeric(10, 2) not null check (price >= 0),
    updated_at timestamptz not null,
    unique (worker_id, service_id)
);

create index idx_worker_service_price_provider_service on worker_service_price (provider_id, service_id);
