create table app_user (
    id uuid primary key,
    email varchar(255) not null unique,
    phone varchar(50),
    display_name varchar(255) not null,
    role varchar(30) not null,
    created_at timestamptz not null
);
