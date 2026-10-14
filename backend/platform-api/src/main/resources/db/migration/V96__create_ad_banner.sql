-- Home-screen promo banners (platform-curated for now; provider_id is for the
-- later business-bought placements; null for a banner the platform runs itself,
-- and a business that is deleted takes its own banners with it).
create table ad_banner (
    id uuid primary key,
    provider_id uuid references provider (id) on delete cascade,
    title varchar(255) not null,
    subtitle varchar(255),
    image_url varchar(2048) not null,
    video_url varchar(2048),
    city_code varchar(255) references city (code),
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    sort_order integer not null default 0,
    status varchar(20) not null default 'DRAFT',
    rejection_reason varchar(500),
    created_at timestamptz not null default current_timestamp,
    updated_at timestamptz not null default current_timestamp,
    constraint ad_banner_window check (ends_at > starts_at)
);

-- The public carousel query: live banners for a city, in order.
create index idx_ad_banner_live on ad_banner (status, starts_at, ends_at);
create index idx_ad_banner_city_code on ad_banner (city_code);
create index idx_ad_banner_provider_id on ad_banner (provider_id);
