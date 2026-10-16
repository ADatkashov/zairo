-- A customer's shortlist of people (masters, mechanics, cleaners, staff): "my master". worker_id is a bare uuid with no
-- FK because the person lives in one of four directories (see WorkerCatalog); user_id references the customer.
create table favorite_worker (
    id uuid primary key,
    user_id uuid not null references app_user (id) on delete cascade,
    worker_id uuid not null,
    created_at timestamptz not null,
    unique (user_id, worker_id)
);
create index idx_favorite_worker_worker_id on favorite_worker (worker_id);
