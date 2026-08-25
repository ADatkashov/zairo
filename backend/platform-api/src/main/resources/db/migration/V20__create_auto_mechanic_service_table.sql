create table auto_mechanic_service (
    id uuid primary key,
    mechanic_id uuid not null references auto_mechanic (id),
    service_id uuid not null references service (id),
    unique (mechanic_id, service_id)
);

create index idx_auto_mechanic_service_mechanic_id on auto_mechanic_service (mechanic_id);
