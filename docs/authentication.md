# Authentication

ZAIRO's customer app (`apps/user_app`) supports four ways to reach the same
account — email + password (existing), Google, Facebook, and phone + OTP —
plus an optional local biometric unlock (Face ID / fingerprint) layered on
top of whichever one a person used to sign in. All four sign-in methods
converge on the same `app_user` row, the same JWT/refresh-token session
(`auth.JwtService`/`auth.RefreshTokenService`), and the same Flutter
`AuthController` — there is no second, parallel authentication mechanism.

```
Google ──────┐
Facebook ────┼──> verified identity ──> app_user ──> ZAIRO session (JWT + refresh token)
Phone + OTP ─┘

Biometric (Face ID / Fingerprint)
    │  local device prompt only — nothing biometric ever leaves the device
    ▼
Unlocks the already-stored refresh token (Keychain / Android Keystore)
    │
    ▼
Restores the ZAIRO session (same /auth/refresh, /auth/me the app already used)
```

## Supported login methods

| Method | Backend endpoint(s) | Flutter entry point |
|---|---|---|
| Email + password | `POST /api/v1/auth/register`, `/login` | `LoginScreen`/`RegisterScreen` (unchanged) |
| Google | `POST /api/v1/auth/google` | `LoginScreen`'s "Continue with Google" |
| Facebook | `POST /api/v1/auth/facebook` | `LoginScreen`'s "Continue with Facebook" |
| Phone + OTP | `POST /api/v1/auth/phone/request-otp`, `/verify-otp` | `PhoneLoginScreen` → `OtpScreen` |

Every one of these returns the exact same `AuthDtos.TokenResponse` shape
(`accessToken`, `refreshToken`, `user`) that `/auth/login` always has —
Flutter's `AuthController._applyTokens` handles all of them identically.

## Identity model

One `app_user` can have several verified identities linked to it — modeled
as its own table, `user_identity` (`provider`, `provider_subject`), rather
than nullable columns bolted onto `app_user` (see `V63` migration and
`auth.UserIdentity`'s own doc comment):

```
app_user (id, email?, phone?, display_name, role, ...)
    │
    ├── user_identity (provider=GOOGLE,   provider_subject=<Google "sub">)
    ├── user_identity (provider=FACEBOOK, provider_subject=<Facebook Graph "id">)
    └── user_identity (provider=PHONE,    provider_subject=<E.164 phone>)
```

`provider_subject` is always the *provider's own* durable identifier —
never anything the client merely claims (email, display name). A unique
constraint on `(provider, provider_subject)` is the database-level guarantee
behind every rule below; see `auth.IdentityLookupService`'s doc comment for
exactly how the application layer avoids racing that constraint instead of
just letting it throw mid-request.

`app_user.email` is now **nullable** (it wasn't before this feature): a
phone-only signup has no email at all, and a Facebook signup that didn't
grant the email permission has none either. `app_user.phone` stays a
display-only column (`UserResponse`), unrelated to authentication — the
`user_identity` row is the actual source of truth for "which phone can this
account use to log in."

### Account linking

An **already-authenticated** caller can attach another provider to their own
account:

| Link Google | Link Facebook | Link phone |
|---|---|---|
| `POST /api/v1/auth/identities/google` | `POST /api/v1/auth/identities/facebook` | `POST /api/v1/auth/identities/phone/verify-otp` |

All three require the caller's own bearer token (`CurrentUser.requireUserId`)
and behave the same way:

- The identity isn't linked to anyone yet → attached to the caller.
- Already linked to the caller → no-op success (idempotent).
- Already linked to someone else → `409 Conflict`
  (`IdentityAlreadyLinkedException`).

**Two identities are never merged just because they share an email.** If
Google hands back a verified email that already belongs to a different
existing account, `POST /auth/google` (the *sign-in* endpoint, not the link
one) is rejected with `409` — the person has to log in with their existing
method first, then link Google to it explicitly from Settings > Security.
An *unverified* email claim is ignored entirely (never even used to look up
an existing account) — see `IdentityService.findOrCreateUser`.

`GET /api/v1/auth/identities` lists what's linked to the caller's own
account (used by the Security screen); nothing exposes another user's linked
identities.

### New-user defaults

A first-time Google/Facebook/phone sign-in creates a `CUSTOMER` — the same
role every self-registered password account gets. `displayName` defaults to
the provider's name claim (Google/Facebook) or the phone number itself
(phone signup) when nothing better is available; `PATCH /api/v1/auth/me`
(`AuthService.updateProfile`) lets the person fill in a real name/email
afterward — the same "minimal profile completion" pattern Register already
used, not a new onboarding framework.

## Google Sign-In

**Flutter** (`GoogleSignInService`, wrapping `google_sign_in`) obtains only
an **ID token** on-device — never a Google access token, never anything
about the account trusted client-side.

**Backend** (`auth.GoogleIdTokenVerifierAdapter`) verifies that token
against Google's own `https://oauth2.googleapis.com/tokeninfo` endpoint (the
server-side verification mechanism Google documents as an alternative to
their client library) rather than reimplementing JWT/JWKS verification:

- **Signature** — verified entirely by Google's endpoint; an invalid
  signature fails the whole HTTP call before any field is read.
- **Expiration** — same: Google rejects an expired token with `400` before
  a body is even returned. Re-checked defensively regardless.
- **Issuer** — must be `accounts.google.com` or `https://accounts.google.com`.
- **Audience** — must be one of `app.oauth.google.client-ids` (below). Left
  blank, no audience is enforced — refused outright in production (see
  "Production configuration checklist").

Every failure — network error, bad signature, wrong issuer/audience, wrong
shape — collapses to the same `401 Invalid Google credential`
(`InvalidProviderCredentialException`); callers are never told *which*
check failed (see that exception's own doc comment).

## Facebook Login

**Flutter** (`FacebookSignInService`, wrapping `flutter_facebook_auth`)
obtains a Facebook **user access token** on-device.

**Backend** (`auth.FacebookGraphIdentityVerifier`) makes two calls to the
Graph API, the Facebook-documented way to verify a client-supplied token
belongs both to a real session *and* to ZAIRO's own app:

1. `GET /debug_token?input_token=<token>&access_token=<appId>|<appSecret>` —
   an app-secret-authenticated call confirming the token is currently valid
   and was issued to *this* app; forging a token that passes this would
   require the app secret itself, which never leaves the server.
2. `GET /me?fields=id,email,name&access_token=<token>` — the actual profile
   lookup, with its `id` cross-checked against step 1's `user_id` so a
   token valid for a different Facebook user can't be substituted here.

`subject` is Graph's `id` (an app-scoped, stable Facebook user id) — never
the client-supplied email/name.

## Phone + OTP

```
Enter phone (PhoneLoginScreen)
    │  POST /auth/phone/request-otp {phone}
    ▼
SMS sent (6-digit code)                 -- always 204, whether or not this
    │                                      phone is already registered, see
    │  POST /auth/phone/verify-otp         "no enumeration" below
    ▼  {phone, code}
ZAIRO session (new or existing account)
```

**Normalization**: any way a number is typed ("+7 700 123 45 67",
"8 (700) 123-45-67", ...) is canonicalized to E.164 (`+77001234567`) by
`auth.PhoneNumberNormalizer` (Google's `libphonenumber`, default region
`KZ`) before it ever touches `user_identity` — otherwise "+7..." and "8..."
would each create a separate account for the same real phone number.

**OTP lifecycle** (`auth.PhoneOtpService`, `phone_otp` table — see `V63`
migration's doc comment for why it's an append-only history, not one row
upserted per phone):

- 6-digit code, generated with `SecureRandom`; only its SHA-256 hash is
  persisted, never the code itself (`PhoneOtp.codeHash`).
- `app.otp.ttl-minutes` (default 5) — expired codes are rejected even if
  correct (`OtpExpiredException`).
- `app.otp.max-verify-attempts` (default 5) — too many wrong guesses against
  the *current* code locks it out (`TooManyOtpAttemptsException`); a new
  `request-otp` call is required.
- `app.otp.resend-cooldown-seconds` (default 60) and
  `app.otp.max-requests-per-hour` (default 5) — abuse protection on the
  request side (`OtpResendCooldownException`/`TooManyOtpRequestsException`).
- One-time use, race-safe: consuming a code is an atomic
  `UPDATE ... WHERE consumed_at IS NULL` (`PhoneOtpRepository.consume`), so
  two concurrent verify calls against the same code can never both succeed
  — see that method's own doc comment.
- **No user enumeration**: `request-otp` always returns `204`, whether or
  not the phone is already registered — same reasoning as the existing
  `POST /auth/forgot-password`.
- The code is delivered by `auth.LoggingOtpSender` — logs it to the server
  console, the same "no real provider account yet" convention
  `notifications.LoggingEmailNotificationProvider` already uses for
  password-reset emails. Replace with a real SMS provider (Twilio, AWS SNS,
  a local telco gateway, ...) behind `OtpSenderPort` — nothing else in this
  feature needs to change.

## Account-creation and identity-linking races

Two concurrent requests for the *same* new identity (two devices signing in
with the same Google account for the first time, or two tabs racing to link
the same phone) must resolve to exactly one account/link, never two. The
database's unique constraint on `(provider, provider_subject)` is the actual
guarantee; `auth.IdentityLookupService`'s doc comment explains the specific
transaction-boundary trick that makes catching that constraint violation and
retrying as a plain lookup actually work under Postgres (a failed statement
aborts the rest of that transaction, so the retry has to run in a genuinely
separate one — a `@Transactional` method on a *different* Spring bean, not a
same-class self-invocation). `IdentityApiTests.
concurrentFirstTimeGoogleSignInsForTheSameIdentityCreateOnlyOneAccount`
exercises this with real concurrent HTTP calls against Testcontainers
Postgres.

## Biometric unlock

Biometric data **never reaches the backend** — there is no endpoint that
accepts a fingerprint, face image, or biometric template, and there never
should be one. `BiometricAuthService` (wrapping `local_auth`) only ever asks
the platform "did the enrolled person just prove presence?" and gets back a
plain `true`/`false`; that's the entirety of what this feature touches.

```
First login (any method above)
    → ZAIRO session issued
    → refresh token written to secure storage (unchanged — already Keychain/
      Keystore-backed, see TokenStorage/SecureStorageService)
    → "Enable Face ID / Fingerprint?" (maybeOfferEnableBiometric) — Enable /
      Not now

Next app launch, if enabled
    → platform biometric prompt (BiometricAuthService.authenticate)
    → success: proceeds to the existing _restoreSession() flow (reads the
      stored access/refresh token, calls /auth/me or /auth/refresh exactly
      as before this feature)
    → declined/failed: treated as logged out for this launch — normal login
      still works; relaunching retries the prompt. Never silently restores
      the session anyway (see AuthController.build's doc comment).
```

Biometric unlock is a **local gate in front of** the refresh token that was
already being stored securely — not a second credential store, and not a
way to mint a new server session on its own. If the refresh token itself has
expired/been revoked, `_restoreSession()`'s existing fallback (unchanged)
clears storage and requires a normal login — a successful fingerprint alone
never creates a session.

`TokenStorage.setBiometricEnabled`/`isBiometricEnabled` is the only new
state this needs, stored in the same secure storage as the tokens
themselves; `TokenStorage.clear()` (called by `logout()`) always clears it
too, so a logout can never be bypassed by "just use your fingerprint."
`BiometricAuthService.isAvailable()` checks both hardware support *and* that
something is actually enrolled — Settings > Security never renders a toggle
that can't work (falls back to a plain "unavailable" message instead).

`POST /api/v1/auth/me/biometric-audit` is audit-only (see "Audit events"
below) — it exists purely so "biometric enabled/disabled" shows up in the
same security event trail as login/OTP events; the backend never stores
biometric enrollment or unlock state, and a failed call to it never blocks
the local toggle the person already confirmed with their own biometric.

## Secure storage

Unchanged from before this feature: `TokenStorage`/`SecureStorageService`
(`packages/core_storage`) already wrap `flutter_secure_storage`, which is
Android Keystore / encrypted-shared-prefs-backed on Android and Keychain-
backed on iOS — no custom cryptography, no plaintext token storage. This
feature reuses that exact mechanism for the same access/refresh tokens
every login method already produced; it does not introduce a second storage
path.

## Threat model coverage

| Threat | Mitigation |
|---|---|
| Provider token forgery | Google: `tokeninfo` signature/issuer/audience/expiry check. Facebook: `debug_token` app-secret-authenticated verification. |
| Wrong audience/issuer, expired OAuth token | Same as above — enforced by the provider's own endpoint, not custom code. |
| Malicious client-supplied email | Never trusted for lookup/creation unless the provider itself reports it verified (`emailVerified`). |
| OTP brute force | `max-verify-attempts` locks out the current code. |
| OTP replay | Atomic one-time consumption (`PhoneOtpRepository.consume`). |
| OTP enumeration | `request-otp` always 204 regardless of registration status. |
| Duplicate identity / race during creation or linking | `(provider, provider_subject)` unique constraint + transactional retry (see "Account-creation and identity-linking races"). |
| Account takeover via matching email | Never auto-merged — see "Account linking". |
| Session theft | Unchanged: short-lived access token + rotating refresh token, same as before. |
| Biometric bypass | Biometric never itself creates a server session; an expired/revoked refresh token still forces normal login. |
| Logout bypass via biometric | `logout()` clears the biometric-enabled flag along with the tokens. |

## Audit events

`auth.AuthAuditLog` logs structured, non-sensitive events (`auth.login.*`,
`auth.otp.*`, `auth.identity.linked`, `auth.biometric.*`) via SLF4J — this
codebase has no dedicated analytics/event-store module for end-user activity
(the one audit table that exists, `platformadmin.PlatformAuditLogService`,
is scoped to platform-admin moderation actions), so a structured log line is
the existing, lightweight mechanism the rest of the codebase already relies
on for this (see `GlobalExceptionHandler`'s own `log.error` calls). **Never**
logs an OTP code, access/refresh token, or raw provider response — the one
deliberate exception is `LoggingOtpSender`, which *is* the SMS delivery
channel standing in for a real gateway (same reasoning as
`LoggingEmailNotificationProvider` logging password-reset codes today).

## Database migration

`V63__create_identity_and_otp_tables.sql`:

- `alter table app_user alter column email drop not null` — backward
  compatible; every existing row already has one, and Postgres allows
  multiple `NULL`s under a unique constraint.
- `create table user_identity (...)` with a unique `(provider,
  provider_subject)` constraint and an index on `user_id`.
- `create table phone_otp (...)` with an index on `(phone, created_at desc)`.

Nothing about existing migrations, existing rows, or the existing
`app_user`/`credential`/`refresh_token` tables changes.

## API surface added

```
POST /api/v1/auth/google                          Sign in / register with Google
POST /api/v1/auth/facebook                         Sign in / register with Facebook
POST /api/v1/auth/phone/request-otp                Request an SMS code
POST /api/v1/auth/phone/verify-otp                 Verify it, sign in / register
POST /api/v1/auth/identities/google                Link Google to the caller
POST /api/v1/auth/identities/facebook              Link Facebook to the caller
POST /api/v1/auth/identities/phone/verify-otp       Link a verified phone to the caller
GET  /api/v1/auth/identities                        List the caller's linked providers
PATCH /api/v1/auth/me                                Complete displayName/email
POST /api/v1/auth/me/biometric-audit                 Audit-only biometric toggle event
```

None of these replace or duplicate an existing endpoint; `/auth/register`,
`/auth/login`, `/auth/refresh`, `/auth/forgot-password`, `/auth/reset-password`,
`/auth/me`, `/auth/me/avatar` are all unchanged.

## Provider configuration

Nothing here is faked — every adapter below is a real integration, just one
that needs real external credentials before it does anything beyond
rejecting every request with "not configured." Nothing about local dev,
CI, or the existing password/email flow requires any of this to be filled
in.

### Backend (environment variables — see `application.yml`'s `app.oauth`/`app.otp` blocks)

| Variable | Used by | Required in production? |
|---|---|---|
| `GOOGLE_OAUTH_CLIENT_IDS` | `GoogleIdTokenVerifierAdapter` — comma-separated Android/iOS/(optional web) OAuth client IDs from [Google Cloud Console](https://console.cloud.google.com/apis/credentials) | Yes — `ProductionSecretsValidator` refuses to boot under `spring.profiles.active=prod` without it |
| `APPLE_CLIENT_IDS` | `AppleIdTokenVerifierAdapter` — comma-separated audiences of Sign in with Apple identity tokens: the iOS bundle id (`com.zairo`), plus a Services ID if Android/web is added | Yes — same startup guard (blank would accept an Apple token issued to any app) |
| `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` | `FacebookGraphIdentityVerifier` — from [Facebook for Developers](https://developers.facebook.com/apps/) → your app → Settings > Basic | No longer required — Facebook sign-in isn't offered in the app (the backend endpoint remains but rejects every token without these) |

`app.otp.*` (TTL, cooldown, attempt/request limits) already have sane
defaults and need no external account to work.

SMS delivery: without Twilio configured, `LoggingOtpSender` only writes the
code to the server log (local dev/CI) — no real SMS reaches a phone. Set these
to send real SMS through Twilio (`TwilioOtpSender`):

| Variable | Notes |
|---|---|
| `TWILIO_ACCOUNT_SID` | Twilio Console > Account Info. Setting it switches delivery from the log to Twilio. |
| `TWILIO_AUTH_TOKEN` | Same place. Required once the SID is set (startup fails otherwise). |
| `TWILIO_FROM` | A Twilio phone number in E.164 (e.g. `+1415...`) that can text Kazakhstan/your target countries. |
| `TWILIO_MESSAGING_SERVICE_SID` | Alternative to `TWILIO_FROM` (starts with `MG`); wins if both are set. |

SMS abuse limits (against SMS-pumping fraud; all in `application.yml`'s `app.otp`):

| Setting (env var) | Default | Meaning |
|---|---|---|
| `max-requests-per-hour` | 5 | codes per phone number per hour (plus a 60 s resend cooldown) |
| `max-requests-per-ip-per-hour` (`OTP_MAX_REQUESTS_PER_IP_PER_HOUR`) | 20 | codes per client IP per hour, across all numbers |
| `daily-send-cap` (`OTP_DAILY_SEND_CAP`) | 3000 | platform-wide codes per 24 h; once reached, requests get 503 (circuit breaker) |
| `allowed-countries` (`OTP_ALLOWED_COUNTRIES`) | `KZ` | ISO countries SMS is sent to (comma-separated, empty = any). `+7` is shared: 7xx = KZ, 9xx = RU |
| `trusted-proxy-hops` (`OTP_TRUSTED_PROXY_HOPS`) | 1 | reverse proxies in front of the app that append to `X-Forwarded-For` (0 if exposed directly) — needed to find the real client IP |

Set `OTP_DAILY_SEND_CAP` to your real traffic and SMS budget, and widen
`OTP_ALLOWED_COUNTRIES` when you open another market. Also set a spending cap in Twilio itself.

In production (`spring.profiles.active=prod`) Twilio is required: `ProductionSecretsValidator`
refuses to start without `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` and one of
`TWILIO_FROM` / `TWILIO_MESSAGING_SERVICE_SID` (otherwise codes would only exist in the server log).

Note: for some countries (incl. Kazakhstan) Twilio may require a registered
alphanumeric sender ID or a messaging service — check Twilio's country
guidelines if messages are not delivered.

### Flutter (`apps/user_app`)

| What | Where | Notes |
|---|---|---|
| Google Android OAuth client ID | Google Cloud Console, associated with the app's release/debug SHA-1 certificate fingerprints | `google_sign_in` on Android reads this via Google Identity Services — no manifest change needed beyond what's already committed. |
| Google iOS OAuth client ID + reversed client ID | Google Cloud Console (iOS client type) | Passed at runtime via `--dart-define=GOOGLE_OAUTH_IOS_CLIENT_ID=...` / `GOOGLE_OAUTH_SERVER_CLIENT_ID=...` (see `GoogleSignInService`); the *reversed* form (`com.googleusercontent.apps.…`) also goes in `GOOGLE_REVERSED_CLIENT_ID` (Xcode build setting — see `ios/Flutter/Debug.xcconfig`/`Release.xcconfig` and `Info.plist`'s `CFBundleURLTypes`). |
| Facebook App ID / Client Token | Facebook for Developers, same app as the backend | `FACEBOOK_APP_ID` / `FACEBOOK_CLIENT_TOKEN` env vars, read by `android/app/build.gradle.kts` (→ `AndroidManifest.xml` meta-data + `fb<APP_ID>` redirect scheme) and by `ios/Flutter/*.xcconfig` (→ `Info.plist`'s `FacebookAppID`/`FacebookClientToken`/`CFBundleURLTypes`). Local dev: `android/local.properties` (gitignored) or the env var, same pattern already used for `MAPS_API_KEY`. |
| Biometric unlock | Nothing to configure | `local_auth` talks to on-device biometric APIs only; no account/credentials of any kind. |

Every one of these defaults to blank and is safe to leave unset: the
corresponding button/flow simply fails cleanly (a rejected provider
credential, or Facebook's SDK reporting it isn't configured) rather than
crashing the app or silently succeeding with a fake identity.

### Android/iOS changes this feature made

- `MainActivity.kt`: `FlutterActivity` → `FlutterFragmentActivity` (required
  by `local_auth_android`'s `BiometricPrompt`, which needs a
  `FragmentActivity` host).
- `AndroidManifest.xml`: `USE_BIOMETRIC` permission; Facebook SDK meta-data
  + `FacebookActivity`/`CustomTabActivity` (Gradle-injected placeholders,
  blank-safe).
- `Info.plist`: `NSFaceIDUsageDescription`; Facebook/Google
  `CFBundleURLTypes` + `LSApplicationQueriesSchemes` (xcconfig-injected,
  blank-safe).

**Not yet verified on a real device/emulator** (this change was developed
without access to Android Studio/Xcode tooling) — before shipping, a real
build should confirm: the `FlutterFragmentActivity` swap doesn't affect the
existing launch theme/splash screen, and the Facebook SDK's required
activities resolve correctly once a real `FACEBOOK_APP_ID` is set.

## Failure / fallback scenarios

- **Provider not configured** (blank client id/app id/secret) → the
  corresponding sign-in button fails with a normal `AuthException`, exactly
  like a wrong password would — never a silent success.
- **Biometric hardware missing or nothing enrolled** → the Security screen
  shows "Biometric login isn't available on this device" instead of a
  toggle (`securityBiometricUnavailable`).
- **Refresh token expired/revoked while biometric is enabled** → biometric
  prompt still succeeds (it's a local check), but the subsequent
  `/auth/me`/`/auth/refresh` call fails the same way it always did →
  `_restoreSession()` clears storage → normal login screen.
- **Two Google/Facebook accounts sharing an email** → the second one to
  attempt sign-in gets `409`, told to log in with the existing method and
  link explicitly — never silently merged.

## Existing-user backward compatibility

- `/auth/register`, `/auth/login`, `/auth/refresh` are byte-for-byte
  unchanged — an existing password account keeps working exactly as before.
- Existing JWTs/refresh tokens are unaffected (same `JwtService`/
  `RefreshTokenService`, same signing key/config).
- Existing roles/authorization are unaffected — new accounts default to
  `CUSTOMER`, the same as before; nothing about `UserRole`/`CurrentUser`
  changed.
- Existing bookings/reviews/favorites/etc. all key off `app_user.id`, which
  this feature never changes for an existing row — an existing user linking
  Google to their account keeps every booking they've ever made.
- `app_user.email` becoming nullable only affects *new* rows created via a
  provider that doesn't supply one; every existing row already has a
  non-null email and is untouched.
