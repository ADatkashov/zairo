create table beauty_master_service (
    id uuid primary key,
    master_id uuid not null references beauty_master (id),
    service_id uuid not null references service (id),
    unique (master_id, service_id)
);

create index idx_beauty_master_service_master_id on beauty_master_service (master_id);
