create table auto_vehicle (
    id uuid primary key,
    owner_user_id uuid not null references app_user (id),
    make varchar(100) not null,
    model varchar(100) not null,
    year integer not null,
    license_plate varchar(20) not null,
    created_at timestamptz not null
);

create index idx_auto_vehicle_owner_user_id on auto_vehicle (owner_user_id);
