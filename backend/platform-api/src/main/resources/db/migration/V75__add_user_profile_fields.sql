-- Personal profile fields a customer can edit themselves.
--
-- birth_date        — lets businesses greet the customer on their birthday and
--                     grant birthday bonuses (day + month matter, year is optional
--                     context only for age checks).
-- gender            — optional; NULL means "prefer not to say".
-- marketing_consent — customer agrees to receive birthday greetings, bonuses and
--                     offers. Defaults to false: nobody is opted in implicitly.

alter table app_user add column birth_date date;
alter table app_user add column gender varchar(20);
alter table app_user add column marketing_consent boolean not null default false;

alter table app_user add constraint chk_app_user_gender
    check (gender is null or gender in ('FEMALE', 'MALE'));

-- Daily "whose birthday is today" lookup (month + day, ignoring year).
create index idx_app_user_birthday on app_user (extract(month from birth_date), extract(day from birth_date))
    where birth_date is not null;
