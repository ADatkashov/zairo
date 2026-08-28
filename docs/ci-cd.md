# CI/CD (GitHub Actions)

This documents what `.github/workflows/` actually does in this repo — not
a generic GitHub Actions primer. It reflects the repo's real structure at
the time it was written (2026-08): a Flutter workspace (`apps/*`,
`packages/*`, plumbed together via `path:` deps + Melos as a local
convenience — see the root `README.md`) and a Spring Boot Gradle
multi-module backend (`backend/`, `platform-api` is the one runnable
module).

## 1. What GitHub Actions does here today

It validates every pull request and every push to `develop`, `test`, or
`master` (this repo's branch chain — see `CLAUDE.md`): Flutter analyze +
test for all six Flutter packages, and Gradle build + test for the whole
backend. On top of that, pushes to those same three branches also
assemble installable artifacts (Android APKs, the backend's bootJar) and
attach them to the workflow run.

It does **not** deploy anything, build a Docker image, or touch any of
`test`/`staging`/`production` as real environments — none of those exist
yet in a form CI could safely target. See §8.

## 2–4. Workflows: what exists, when they run, what they check

### `flutter-ci.yml`

**Triggers:** `pull_request` and `push` on `develop`, `test`, `master`.

**What it does:** a matrix job, one run per Flutter package —
`apps/user_app`, `apps/business_admin`, `packages/core_network`,
`packages/core_region`, `packages/core_storage`, `packages/core_ui`.
Each one gets its own `flutter pub get` → `flutter analyze` →
`flutter test`, in its own directory (no melos in CI — path
dependencies resolve on their own via plain `pub get`, so melos isn't
needed to make this work, only to run it across every package with one
command locally).

A `dart format --set-exit-if-changed` step also runs, but with
`continue-on-error: true` — **it cannot fail the build**. A one-time
check while building this found that a from-scratch format pass would
touch 115 of 191 tracked Dart files. That's not a correctness problem —
the repo simply never had a formatting gate before — but it means
turning this into a real gate today would fail on every existing PR for
reasons unrelated to whatever that PR actually changed. See §9 for how
to flip it to blocking once that's been cleaned up once.

### `backend-ci.yml`

**Triggers:** same as above — `pull_request` and `push` on `develop`,
`test`, `master`.

**What it does:** one job — JDK 21 (matching
`backend/build.gradle.kts`'s `JavaLanguageVersion.of(21)` toolchain),
Gradle via `gradle/actions/setup-gradle` (wrapper checksum validation +
caching), then `./gradlew build` from `backend/`. `build` runs
`check` (which runs every module's tests) and `assemble` in one
invocation — it covers both "Backend Tests" and "Backend Build" from
the target pipeline shape.

Postgres needs no setup here: `platform-api`'s
`TestcontainersConfiguration` spins up a real `postgres:17-alpine`
container per test run via Testcontainers, using the Docker daemon
already present on GitHub-hosted Ubuntu runners. **MinIO is different**
— `StorageApiTests`' own javadoc says so explicitly: it isn't
Testcontainerized, so it's started as a plain `docker run` step before
the Gradle build, using the exact image, ports, and dev credentials
`infrastructure/docker-compose.yml` already uses locally
(`app_factory` / `app_factory_secret`, bucket `factory-media`). It's
`docker run` and not a `services:` container because the official
`minio/minio` image has no default `CMD` — `services:` has no field for
supplying one, so the workflow starts and health-checks it as an
explicit step instead.

On failure, `backend/**/build/reports/tests/**` (JUnit HTML reports) are
uploaded as a workflow artifact for 14 days so a failure can be
inspected without re-running Gradle locally.

### `build-artifacts.yml`

**Triggers:** `push` only, on `develop`, `test`, `master` — never on a
PR. It doesn't re-validate anything (the two workflows above already
did that for whatever got merged); it only builds outputs.

**What it does:** two independent jobs.

- `android-apk` (matrix: `user_app`, `business_admin`) — `flutter build
  apk --release`, uploads `app-release.apk` as
  `<app>-apk-debug-signed`. That name is accurate, not decorative: both
  apps' `android/app/build.gradle.kts` point the `release` build type at
  `signingConfigs.getByName("debug")`. The APK is real and installable,
  but it is **debug-signed** — fine for internal QA, not something to hand
  to the Play Store. For a real release-signed APK/AAB, see §10.
- `backend-jar` — `./gradlew :platform-api:bootJar`, uploads the
  resulting executable jar (excluding the `-plain.jar` Spring Boot's
  plugin also leaves in `build/libs/`, which is classes-only and not
  runnable).

Neither job publishes anywhere — "uploaded to the workflow run,
downloadable from there" is the whole distribution mechanism today.

## 5. Reading a failed CI job

1. Open the PR (or the push) → **Checks** tab → the red job.
2. `flutter-ci.yml` failures: the job name says which package failed
   (`flutter (apps/user_app)`, etc.) — expand the failing step
   (`flutter analyze` or `flutter test`) for the actual error. The
   `dart format` step is never the reason a job is red (see §3).
3. `backend-ci.yml` failures: expand **Build and test (./gradlew
   build)**. A compile error surfaces there directly; a test failure
   also does, but the uploaded `backend-test-reports` artifact (bottom
   of the run summary page) has the full per-test HTML report, which is
   easier to read than the raw Gradle log for a large failure. If the
   **Wait for MinIO to be ready** step is what's red instead, that's an
   infrastructure flake (MinIO didn't come up in 30s), not a code
   problem — re-run the job.
4. `build-artifacts.yml` failures don't block anything (nothing required
   this workflow — see §7 of the branch-protection recommendation
   below), but a red run here means the APK/jar for that push isn't
   available to download.

## 6. Where secrets should live

The Android release-signing keystore and its passwords (§10) are the
first real secrets this repo's CI uses — six of them, in **GitHub →
Settings → Secrets and variables → Actions**, referenced as
`${{ secrets.NAME }}` and never in a workflow file, a `.env`, or source.
Everything else these workflows touch (the JWT secrets and MinIO
credentials in `backend/platform-api/src/main/resources/application.yml`)
is still a dev-only value committed in plaintext, by this repo's own
explicit design — see that file's comments ("dev-only secret, fine to
commit — must move to an env var / secrets manager before any real
deployment"). CI reuses those same dev values; nothing new needed
hardcoding there.

When the next real secret shows up (a production JWT secret, a container
registry token, a deploy credential), it belongs in the same place. Once
real `test`/`staging`/`production` targets
exist, prefer **GitHub Environments** (Settings → Environments) over
repository-wide secrets: each environment gets its own secret values
(so a `staging` deploy job physically cannot read a `production`
credential) and can require manual approval before a job that uses it
runs. Nothing in this repo needs that split yet — there's exactly one
config (`application.yml`, dev defaults), not per-environment configs.

## 7. How artifacts are generated

Every artifact comes from `build-artifacts.yml`, only on a push to
`develop`, `test`, or `master` (never on a PR — see §3). From a
workflow run's summary page, the **Artifacts** section lists:

- `user_app-apk-debug-signed`
- `business_admin-apk-debug-signed`
- `platform-api-bootjar`

**`MAPS_API_KEY` secret (optional)** — if set (**GitHub → Settings →
Secrets and variables → Actions → New repository secret**, name
`MAPS_API_KEY`, value a real Google Maps API key restricted to
`com.zairo` — see `docs/PRODUCT_PRODUCTION_ROADMAP.md` section 13, 0.5),
`user_app`'s APK renders a real Google Map instead of the placeholder
(`GoogleMapsRenderer` vs `MockMapRenderer`, see
`apps/user_app/lib/features/maps/presentation/providers/maps_providers.dart`).
Unset is a safe default, not a broken build — the APK still builds and
just keeps showing the placeholder. Restricting the key by SHA-1
fingerprint matters here specifically: this workflow's `flutter build apk
--release` is still debug-signed (see the note above), so the fingerprint
to register in Google Cloud Console is the standard Android debug
keystore's — register a second fingerprint (or a second, unrestricted-by-
fingerprint key) for the real release-signed build from `android-release.yml`
(§10), which wires the same `MAPS_API_KEY` secret the same way and is
signed with the real upload keystore's certificate instead.

each downloadable as a zip, retained 14 days. `backend-test-reports`
also appears here, but only on a `backend-ci.yml` run that failed.

## 8. What is intentionally NOT automated yet

- **No deployment of any kind.** There is no existing deploy mechanism
  (no Dockerfile, no Kubernetes manifests, no cloud provider config, no
  prior `.github/` at all before this change) for CI to hook into, and
  the task this was built from was explicit: don't invent one.
- **No Docker image build.** No `Dockerfile` exists anywhere in the
  repo. Note for later: `platform-api` already gets a `bootBuildImage`
  Gradle task for free from the `org.springframework.boot` plugin
  (Cloud Native Buildpacks — no Dockerfile needed), so adding a
  container image is a smaller lift than "write a Dockerfile from
  scratch" whenever it's actually needed.
- ~~No release-signed Android build / no AAB.~~ **Done — see §10.**
  `android-release.yml` produces a real release-signed APK and AAB on
  manual dispatch. `build-artifacts.yml`'s automatic per-push APK stays
  debug-signed on purpose (see its own description above) — that one is
  for quick internal QA, not something to hand to the Play Store.
- **No iOS build.** Both apps have an `ios/` directory, but iOS builds
  require a macOS runner (`macos-latest`) and code signing
  (Apple Developer certificate + provisioning profile) — neither is set
  up, and GitHub-hosted Linux runners can't build iOS at all. Not
  attempted here.
- **No `dart format` enforcement.** Explained in §3 — it's report-only
  until a one-time cleanup PR lands.
- **No integration/E2E tests.** There is no `integration_test/`
  directory in either app today — only unit/widget tests under each
  package's `test/`. Nothing was skipped; there's nothing there to run.
- **No required branch-protection rules configured — and currently
  can't be, from this account.** Attempted via the API (2026-08-28):
  `GET/PUT /repos/.../branches/{branch}/protection` returns 403 —
  `"Upgrade to GitHub Pro or make this repository public to enable
  this feature."` Branch protection on a *private* repo needs GitHub
  Pro/Team/Enterprise; this repo is private on a plan that doesn't
  include it. Two ways past this, both a deliberate choice for
  whoever owns the account, not a code change: upgrade the account to
  Pro, or make the repo public. Until one of those happens, CI still
  runs and reports status on every PR/push exactly as documented above
  — nothing merges without a human choosing to click merge on a red
  check, but nothing *blocks* them either.

  Once branch protection is available, the required checks should be:
  `backend (build + test)` and every `flutter (<package>)` matrix job,
  on PRs targeting `develop`, `test`, and `master`. Do **not** require
  `build-artifacts.yml` — it never runs on a PR, so requiring it would
  leave every PR's checks stuck pending forever. Use
  `required_status_checks.contexts` (or the newer `checks` array) with
  `strict: false` — `strict: true` would force a `develop`→`test` PR to
  re-run CI every time someone pushes to `develop` again before it
  merges, which doesn't fit this repo's fast-moving-`develop` workflow.
  Leave `required_pull_request_reviews` and `restrictions` unset: this
  repo's convention is direct pushes to `develop` with no PR (see
  `CLAUDE.md`) — required status checks alone don't block that (they
  only gate the PR merge button/API), but requiring reviews or
  restricting who can push would.
- **No Redis usage in CI (or in the app).** `infrastructure/docker-compose.yml`
  provisions a Redis container for local dev, but nothing in
  `backend/` actually connects to Redis yet — grepping the whole
  backend for `redis`/`Redis` turns up nothing outside that one
  `README.md` mention. Nothing to wire into CI until that changes.

## 9. Recommended next CI/CD phases

In rough priority order, each one unblocked by evidence gathered while
building this, not guessed at:

1. **One-time `dart format .` cleanup PR**, entirely mechanical (no
   logic changes), then flip `flutter-ci.yml`'s format step from
   `continue-on-error: true` to a real gate
   (`--set-exit-if-changed` already does the enforcement — just drop
   the `continue-on-error` line once the repo is clean).
2. **Turn on required status checks** in branch protection for
   `develop`, `test`, and `master`, per the exact list in §8 — this is
   the actual "PR CI" enforcement; right now these workflows run and
   report but nothing stops a merge if they're red.
3. **A real Docker image for `platform-api`**, most cheaply via the
   Spring Boot Gradle plugin's built-in `bootBuildImage` task (see §8) —
   no Dockerfile needed to get started. This is the actual prerequisite
   for everything below the "Docker Image" box in the target pipeline —
   right now there is nothing to deploy *to* a `test` environment even
   if one existed.
4. ~~**Android release signing**~~ **Done — see §10.**
5. **GitHub Environments for `test` → `staging` → `production`**, each
   with its own secrets and (for `staging`/`production`) a required
   reviewer, once there's an actual place each of those points at. This
   is where the target pipeline's bottom three boxes become real —
   deliberately not built now, per §8.

## 10. Android release signing

A real, Play-Store-eligible release build now exists, kept deliberately
separate from the always-on `build-artifacts.yml` pipeline (see §8's
note): `android-release.yml`, triggered manually
(**Actions → Android Release → Run workflow**, pick `both` or one app).
It produces a **release-signed APK and AAB** and publishes both as a
**GitHub Release** — a permanent page with a stable download link,
openable straight from a phone browser (repo → **Releases** tab, or the
link the workflow run prints). Unlike `build-artifacts.yml`'s workflow-run
artifacts, a GitHub Release never expires and isn't zipped.

It also wires the optional `secrets.MAPS_API_KEY` the same way
`build-artifacts.yml` does (see §7) — if that secret is set, `user_app`'s
release build renders a real Google Map instead of the placeholder;
unset, it's a safe default, not a broken build.

### How it works

`apps/*/android/app/build.gradle.kts` reads `android/key.properties` (one
level up from `app/`) if it exists, and builds a real
`signingConfigs.release` from it. If that file is **absent**, the build
falls back to the debug keystore exactly as before — a checkout with no
`key.properties` still builds `flutter build apk --release` /
`flutter run --release` unchanged, so nothing about local dev or the
existing `build-artifacts.yml` job changed.

`key.properties` is never committed (`.gitignore` excludes it, plus every
`*.jks`/`*.keystore` file) — it's either hand-created locally by a dev
(see below), or written by `android-release.yml` itself from GitHub
Secrets, immediately before the build and deleted again immediately after
(its `Remove decoded keystore and key.properties` step, `if: always()`).

**One shared keystore, two key aliases** — one `ANDROID_KEYSTORE_BASE64`
secret covers both apps; `user_app` and `business_admin` each sign with
their own alias inside it, so a compromised/rotated alias for one app
doesn't require touching the other's.

### Required GitHub Secrets

Add these under **repo → Settings → Secrets and variables → Actions → New
repository secret**. All six are required before `android-release.yml`
can succeed — it checks for them explicitly and fails with a clear
`::error::` naming whichever are missing, rather than an opaque Gradle
signing failure.

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64-encoded, as one line |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore's store password (shared by both aliases) |
| `ANDROID_KEY_ALIAS_USER_APP` | Key alias for `user_app` inside the keystore |
| `ANDROID_KEY_PASSWORD_USER_APP` | That alias's key password |
| `ANDROID_KEY_ALIAS_BUSINESS_ADMIN` | Key alias for `business_admin` inside the keystore |
| `ANDROID_KEY_PASSWORD_BUSINESS_ADMIN` | That alias's key password |

### Generating a keystore from scratch

Only needed once (or if the keystore is ever lost/rotated — see the
warning below). Requires a JDK (`keytool` ships with it). One keystore,
two aliases:

```bash
keytool -genkeypair -v \
  -keystore zairo-release-upload.jks \
  -storetype JKS \
  -alias user_app_upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Zairo User App, OU=Factory, O=Zairo, L=Almaty, ST=Almaty, C=KZ"

keytool -genkeypair -v \
  -keystore zairo-release-upload.jks \
  -storetype JKS \
  -alias business_admin_upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Zairo Business Admin, OU=Factory, O=Zairo, L=Almaty, ST=Almaty, C=KZ"
```

(`-validity 10000` ≈ 27 years — Google requires an upload key's
certificate to stay valid well past 2033; the `-dname` values are cosmetic
certificate metadata, not app-facing, safe to customize or leave as-is.)
Both commands prompt for a store password on first use, then a key
password per alias — pick strong, distinct values and record them; they
become `ANDROID_KEYSTORE_PASSWORD` and the two `ANDROID_KEY_PASSWORD_*`
secrets above.

Then base64-encode it for the `ANDROID_KEYSTORE_BASE64` secret:

```bash
base64 -w0 zairo-release-upload.jks > zairo-release-upload.jks.base64
```

Paste the resulting single-line file's contents as the secret value.

**⚠️ Back this keystore up somewhere durable outside GitHub (a password
manager, encrypted storage) the moment it's created.** If it's lost, there
is no way to publish an *update* to an app already on the Play Store under
the same listing — Google ties every release of a given `applicationId` to
its original upload key. GitHub Secrets are write-only (nothing, including
this workflow, can ever read one back out to display it) — they are not a
backup.

### Building a signed release locally (optional)

A developer can build a real release-signed APK/AAB on their own machine
without touching CI or any secret above: create
`apps/<app>/android/key.properties` (gitignored) pointing at their own
copy of the keystore:

```properties
storeFile=/absolute/or/relative/path/to/zairo-release-upload.jks
storePassword=...
keyAlias=user_app_upload
keyPassword=...
```

then `flutter build apk --release` / `flutter build appbundle --release`
as usual — no other setup needed, since `build.gradle.kts` reads this file
exactly the same way CI does.

### Pointing the app at a backend (`api_base_url` input)

Neither app has a deployed backend to talk to (see §1/§8) — every APK's
`baseUrl` is either an auto-detected default (`apps/*/lib/core/constants/
environment.dart`: `localhost` on web/desktop/iOS simulator, the
Android-emulator-only alias `10.0.2.2` on an emulator) or the value baked
in via `--dart-define=API_BASE_URL=...`. A **physical phone can reach
neither auto-detected default** — it needs your computer's real LAN IP.

To test a release build on a real device over the same Wi-Fi network as
your computer:

1. Start the backend on your computer: `cd infrastructure && docker
   compose up -d` (Postgres/Redis/MinIO), then `cd ../backend && ./gradlew
   :platform-api:bootRun`.
2. Find your computer's LAN IP (**not** `localhost`/`127.0.0.1`) —
   `ipconfig` (Windows, look for `IPv4 Address`) or `ifconfig`/`ip addr`
   (macOS/Linux). It looks like `192.168.x.x`.
3. Allow inbound connections to port 8080 in your computer's firewall
   (Windows Defender Firewall blocks this by default).
4. When running **Android Release** (below), set the `api_base_url` input
   to `http://<that IP>:8080/api/v1` — include the `/api/v1` suffix.

The GitHub Release's notes record which backend URL got baked into that
particular build, so it's never a guess later which APK talks to what.

Once a real deployed backend exists, this same input takes its public
URL instead — nothing about the mechanism changes.

### Getting the APK onto a phone

1. **Actions** tab → **Android Release** (left sidebar) → **Run workflow**
   → pick the branch, which app(s), and optionally `api_base_url` (see
   above) → **Run workflow**.
2. Once it finishes, open the repo's **Releases** page (or the direct link
   printed at the end of the `Publish GitHub Release` step) on the phone.
3. Tap the `.apk` asset to download it, then open the downloaded file to
   install (Android will prompt to allow installs from that source the
   first time). The `.aab` asset isn't installable directly — it's for
   uploading to Google Play Console.

## 11. Postman collection (dev tool, not CI)

Not a workflow, not something CI touches — noted here since it's the
same "don't hand-maintain what's already generated" spirit as §9.1.
`scripts/sync-postman.sh` regenerates a Postman collection from the
backend's live OpenAPI spec (`GET /v3/api-docs`) via Postman's own
`openapi-to-postmanv2` converter, run through `npx` (needs Node.js
locally; nothing installs globally). Requires the backend running
(`cd backend && ./gradlew bootRun`), then:

```
./scripts/sync-postman.sh
```

Writes to `docs/local/` — gitignored on purpose, so the collection
never goes stale in git the way a committed export would. Re-run it
whenever the API changes and you want a fresh import for manual
testing in Postman.
