create table cleaning_cleaner_service (
    id uuid primary key,
    cleaner_id uuid not null references cleaning_cleaner (id),
    service_id uuid not null references service (id),
    unique (cleaner_id, service_id)
);

create index idx_cleaning_cleaner_service_cleaner_id on cleaning_cleaner_service (cleaner_id);
