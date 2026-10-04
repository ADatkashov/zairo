-- Passkeys (WebAuthn). A passkey is a public-key credential held by the
-- person's device/password manager; only the public half is stored here.
create table passkey_credential (
    id uuid primary key,
    user_id uuid not null references app_user (id),
    credential_id bytea not null,
    public_key_cose bytea not null,
    sign_count bigint not null default 0,
    name varchar(100) not null,
    created_at timestamptz not null,
    last_used_at timestamptz,
    constraint uq_passkey_credential_credential_id unique (credential_id)
);

create index idx_passkey_credential_user_id on passkey_credential (user_id);

-- In-flight registration/login ceremonies: the server-issued options
-- (including the challenge) must be remembered between "start" and "finish".
-- Single-use and short-lived: a row is deleted the moment it is consumed.
create table webauthn_ceremony (
    id uuid primary key,
    kind varchar(16) not null,
    user_id uuid,
    request_json text not null,
    expires_at timestamptz not null,
    created_at timestamptz not null
);

create index idx_webauthn_ceremony_expires_at on webauthn_ceremony (expires_at);
