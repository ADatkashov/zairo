-- Customer Intelligence foundation: deterministic, persisted behaviour
-- profiles computed from real booking history, so Revenue Engine
-- strategies and business-admin surfaces can read them cheaply instead of
-- re-deriving them from booking/availability_slot on every call. See
-- customerintelligence's own package-info.java for the full design.
--
-- Cross-module ids (user_id, provider_id, employee_id, favourite_*_id) are
-- bare uuid columns with no FK, matching this codebase's established
-- convention (see docs/erd/core-domain.md), same as smart_fill_campaign
-- (V51) and rebook_campaign (V53).
create table customer_profile (
    id uuid primary key,
    user_id uuid not null,
    total_completed_bookings int not null default 0,
    total_cancelled_bookings int not null default 0,
    total_no_shows int not null default 0,
    total_spent numeric(12, 2) not null default 0,
    currency varchar(3),
    average_booking_value numeric(12, 2),
    first_booking_at timestamptz,
    last_booking_at timestamptz,
    last_completed_booking_at timestamptz,
    average_visit_interval_days int,
    preferred_booking_days varchar(100),
    preferred_time_range varchar(20) not null default 'UNKNOWN',
    attendance_rate double precision,
    cancellation_rate double precision not null default 0,
    repeat_booking_rate double precision not null default 0,
    customer_value_score numeric(5, 2) not null default 0,
    next_expected_visit_at timestamptz,
    retention_status varchar(20) not null default 'NEW',
    favourite_provider_id uuid,
    favourite_service_id uuid,
    last_calculated_at timestamptz not null,
    version bigint not null default 0
);

create unique index idx_customer_profile_user_id on customer_profile (user_id);
create index idx_customer_profile_retention_status on customer_profile (retention_status);

create table customer_provider_profile (
    id uuid primary key,
    user_id uuid not null,
    provider_id uuid not null,
    total_bookings int not null default 0,
    completed_bookings int not null default 0,
    cancelled_bookings int not null default 0,
    no_shows int not null default 0,
    total_spent numeric(12, 2) not null default 0,
    currency varchar(3),
    average_booking_value numeric(12, 2),
    first_visit_at timestamptz,
    last_visit_at timestamptz,
    average_visit_interval_days int,
    next_expected_visit_at timestamptz,
    preferred_booking_days varchar(100),
    preferred_time_range varchar(20) not null default 'UNKNOWN',
    attendance_rate double precision,
    cancellation_rate double precision not null default 0,
    retention_status varchar(20) not null default 'NEW',
    favourite_employee_id uuid,
    favourite_service_id uuid,
    relationship_score numeric(5, 2) not null default 0,
    last_calculated_at timestamptz not null,
    version bigint not null default 0
);

create unique index idx_customer_provider_profile_user_provider on customer_provider_profile (user_id, provider_id);
-- Revenue Engine's candidate-pool bulk read (CustomerIntelligenceService.findProviderProfiles)
-- and the business-admin "customers due for rebooking" query pattern.
create index idx_customer_provider_profile_provider_retention on customer_provider_profile (provider_id, retention_status);

create table customer_employee_profile (
    id uuid primary key,
    user_id uuid not null,
    provider_id uuid not null,
    employee_id uuid not null,
    completed_bookings int not null default 0,
    total_spent numeric(12, 2) not null default 0,
    currency varchar(3),
    last_visit_at timestamptz,
    average_visit_interval_days int,
    favourite_service_id uuid,
    relationship_score numeric(5, 2) not null default 0,
    last_calculated_at timestamptz not null,
    version bigint not null default 0
);

create unique index idx_customer_employee_profile_user_provider_employee
    on customer_employee_profile (user_id, provider_id, employee_id);
create index idx_customer_employee_profile_provider_employee on customer_employee_profile (provider_id, employee_id);
