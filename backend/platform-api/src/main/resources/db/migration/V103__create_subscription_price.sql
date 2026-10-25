-- What a paid plan costs per month, editable by PLATFORM_ADMIN at runtime (see SubscriptionPricing). A plan without a
-- row keeps the previous behaviour: the built-in price in the platform's default currency, so nothing changes until
-- somebody sets a price. The price a renewal actually charges is read when the charge is made; past charges keep the
-- amount they were created with.
create table subscription_price (
    plan varchar(32) primary key,
    monthly_price numeric(12, 2) not null check (monthly_price > 0),
    currency varchar(3) not null,
    updated_at timestamptz not null,
    updated_by varchar(255)
);
