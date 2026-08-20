create table beauty_portfolio_item (
    id uuid primary key,
    master_id uuid not null references beauty_master (id),
    image_url varchar(500) not null,
    caption varchar(500),
    created_at timestamptz not null
);

create index idx_beauty_portfolio_item_master_id on beauty_portfolio_item (master_id);
