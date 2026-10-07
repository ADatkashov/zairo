-- Owner-managed weekly schedule of a worker (any of the four directories). A worker WITH a row here has their own
-- generated slots (availability_slot.employee_id = worker_id); one WITHOUT keeps using the business's shared slots.
create table worker_schedule (
    worker_id uuid primary key,
    provider_id uuid not null references provider (id),
    zone_id varchar(64) not null,
    slot_minutes integer not null check (slot_minutes > 0),
    break_minutes integer not null default 0 check (break_minutes >= 0),
    created_at timestamptz not null,
    updated_at timestamptz not null
);

create index idx_worker_schedule_provider_id on worker_schedule (provider_id);

-- One or more working intervals per weekday (a lunch break is simply two intervals). day_of_week: 1 = Monday .. 7 = Sunday.
create table worker_work_hours (
    id uuid primary key,
    worker_id uuid not null references worker_schedule (worker_id) on delete cascade,
    day_of_week integer not null check (day_of_week between 1 and 7),
    start_time time not null,
    end_time time not null,
    check (start_time < end_time)
);

create index idx_worker_work_hours_worker_id on worker_work_hours (worker_id);

-- Days off, sick leave, vacation: the worker can't be booked in [starts_at, ends_at).
create table worker_time_off (
    id uuid primary key,
    worker_id uuid not null,
    provider_id uuid not null references provider (id),
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    reason varchar(255),
    created_by uuid not null,
    created_at timestamptz not null,
    check (starts_at < ends_at)
);

create index idx_worker_time_off_worker_id on worker_time_off (worker_id, ends_at);
create index idx_worker_time_off_provider_id on worker_time_off (provider_id);

-- Per-business rules the owner controls. A business with no row uses the defaults below.
create table provider_workforce_settings (
    provider_id uuid primary key references provider (id),
    allow_worker_choice boolean not null default true,
    worker_pricing_enabled boolean not null default false,
    updated_at timestamptz not null
);
