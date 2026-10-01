-- Multi-provider auth (see docs/adr and auth module package-info): one
-- app_user can now be reached through several verified identities (Google,
-- Facebook, phone+OTP) instead of only email+password. Existing rows are
-- untouched — nothing here changes how the current email/password flow
-- works, only what else can point at the same app_user.id.

-- email was `not null unique`. A phone-only or Facebook-without-email
-- signup has no email to put there. Postgres unique constraints already
-- allow any number of NULLs (NULL is never equal to NULL), so dropping
-- NOT NULL is sufficient — no partial index needed.
alter table app_user alter column email drop not null;

-- One row per verified external identity, pointing back at the app_user it
-- belongs to. provider_subject is the provider's own stable id: Google's
-- "sub" claim, Facebook's Graph "id" field, or the E.164-normalized phone
-- number for PHONE. The (provider, provider_subject) unique constraint is
-- the last line of defense against two concurrent logins/links racing to
-- create two identities (and, for PHONE, two accounts) for the same
-- external identity — see IdentityService.
create table user_identity (
    id uuid primary key,
    user_id uuid not null references app_user (id),
    provider varchar(20) not null,
    provider_subject varchar(255) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    constraint uq_user_identity_provider_subject unique (provider, provider_subject)
);

create index idx_user_identity_user_id on user_identity (user_id);

-- One row per OTP ever issued for a phone number (not just the latest) —
-- kept as a full history rather than upserted in place, both so
-- resend-cooldown/rate-limit checks (see PhoneOtpService) can look at how
-- many requests landed in a recent window, and so a consumed/expired code
-- can never come back to life. code_hash is a salted-free SHA-256 digest of
-- the 6-digit code, same hashing shape as RefreshToken.tokenHash — the code
-- itself is never persisted, and a leaked row is useless on its own (the
-- real protections are expiry + one-time consumption + attempts, not the
-- hash's strength against a 6-digit keyspace).
create table phone_otp (
    id uuid primary key,
    phone varchar(32) not null,
    code_hash varchar(255) not null,
    attempts int not null default 0,
    expires_at timestamptz not null,
    consumed_at timestamptz,
    created_at timestamptz not null
);

create index idx_phone_otp_phone_created_at on phone_otp (phone, created_at desc);
