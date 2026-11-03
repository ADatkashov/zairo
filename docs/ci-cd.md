# CI/CD (GitHub Actions)

This documents what `.github/workflows/` actually does in this repo — not
a generic GitHub Actions primer. It reflects the repo's real structure at
the time it was written (2026-08): a Flutter workspace (`apps/*`,
`packages/*`, plumbed together via `path:` deps + Melos as a local
convenience — see the root `README.md`) and a Spring Boot Gradle
multi-module backend (`backend/`, `platform-api` is the one runnable
module).

## 1. What GitHub Actions does here today

Since 2026-10 it is deliberately **narrow** (the repo is private: 2000 free minutes a month, see
"Actions minutes" below): Flutter analyze + test for all seven packages and the Gradle build + test of the
backend run **only on a push to `test`** (what you get when you merge develop -> test), or when started by hand
(*Actions -> run workflow*). Nothing runs on pull requests, on `develop` or on `master`.

GitHub Actions itself still does **not** deploy anything. The artifact workflows are kept as `*.yml.disabled`.

## Actions minutes

What was checked before anything was switched on (2026-10-19):

- The repo is **private**, so Actions bills against the plan's 2000 free minutes a month (Linux x1).
- Until now the workflows ran on every PR and every push to develop/test/master, and Dependabot (weekly, up to
  ~20 PRs) added a CI run per PR plus its own Dependabot-update jobs. The last runs (to 2026-09-29) failed in 3-6
  seconds with no steps: the account was blocked by billing, so they used no minutes, but the moment the block
  is lifted all of that would have started to burn them.

What is done so the quota is not spent:

| Measure | Effect |
|---|---|
| Triggers cut to `push: [test]` + manual `workflow_dispatch` | No run on PRs (a PR into `test` plus its merge push would count twice), none for develop/master |
| `paths-ignore`: `*.md`, `docs/`, `scripts/`, `.circleci/` | A docs-only merge costs 0 minutes |
| Flutter: one job instead of a 7-package matrix | The SDK is set up once, not 7 times; every job is rounded up to a whole minute |
| Removed the report-only `dart format` step | One step less per package |
| `timeout-minutes` (backend 30, flutter 40) | A hung run cannot burn minutes for hours |
| `concurrency` with `cancel-in-progress` | A newer push cancels a run still going |
| Dependabot switched off (`dependabot.yml.disabled`) | No update jobs, no PR-triggered CI |
| CircleCI switched off (kept) | No second CI running in parallel |

Rough budget (an estimate, not measured: backend ~15-20 min, Flutter ~10-15 min): about 30 minutes per push to
`test`, i.e. roughly 60 runs a month. Watch the real figure in *Settings -> Billing -> Usage* after the first
runs. Also set a spending limit of $0 there so that nothing is ever charged past the free minutes.

Switching things back:

- **Dependabot:** rename `.github/dependabot.yml.disabled` to `dependabot.yml`.
- **CircleCI:** in `.circleci/config.yml` replace `circleci-switch` with `test` in the branch filters.
- **More branches in Actions:** add them to `on.push.branches` in the two workflows.

### Self-hosted runner

GitHub-hosted runners need Actions minutes/billing; a self-hosted runner on your own machine does not. Both
workflows pick their runner from the repo variable `CI_RUNS_ON` (unset = `ubuntu-latest`), so no code change is
needed to switch.

1. On a Linux x64 machine with Docker (the user must be in the `docker` group): GitHub -> repo *Settings -> Actions ->
   Runners -> New self-hosted runner*, copy the registration token (valid 1 hour).
2. `scripts/setup-self-hosted-runner.sh <token>` — downloads the runner, registers it and installs it as a service.
3. *Settings -> Secrets and variables -> Actions -> Variables*: add `CI_RUNS_ON` = `["self-hosted","linux"]`.
4. Run *Actions -> Backend CI / Flutter CI -> Run workflow* to check it. To go back to GitHub-hosted, delete the variable.

**On Windows:** run the runner inside WSL2, not as a native Windows runner (the workflows are bash + Linux containers).
1. PowerShell (admin): `wsl --install -d Ubuntu`, reboot, create the Ubuntu user.
2. Docker Desktop -> *Settings -> Resources -> WSL integration*: enable Ubuntu. Check `docker ps` works inside Ubuntu.
3. Optional, so the runner can be a service: in Ubuntu `sudo sh -c 'printf "[boot]\nsystemd=true\n" >> /etc/wsl.conf'`, then
   `wsl --shutdown` from PowerShell. Without systemd the script tells you to start `~/actions-runner/run.sh` by hand
   and keep that terminal open.
4. In Ubuntu: `git clone` the repo (or just copy the script) and continue from step 2 above.
The PC must be on, with WSL and Docker Desktop running, while CI runs.

Notes: the runner is persistent, so caches (Gradle, pub, Flutter SDK) stay on its disk and are faster; when `CI_RUNS_ON`
is set the workflows skip the GitHub cloud caches (they count against the 0.5 GB Actions storage quota) and failure
artifacts are kept 3 days; the machine must be on
when you push to `test`, otherwise the job waits in the queue. The workflows only run on pushes to `test` and by hand,
never on pull requests, so outside contributors cannot run code on the runner — keep it that way for a private repo
runner (do not add `pull_request` triggers from forks).

### APK on your phone without GitHub Actions

`build-artifacts.yml` is disabled, so build locally in Ubuntu/WSL: once `scripts/setup-local-dev-wsl.sh`, then
`scripts/setup-android-sdk-wsl.sh`; after that `scripts/build-apk-local.sh [user_app|business_admin|platform_admin]` puts
`<app>-debug-signed.apk` in `build-apk-out/` (same `--dart-define` flags as the workflow; API URL defaults to the live
Render backend). Open the folder from Windows with `explorer.exe "$(wslpath -w build-apk-out)"`, copy the APK to the phone
(cable, Telegram, Drive) and install it (allow "install unknown apps"). The first build is long: Gradle downloads the Android
platform/build-tools. Without a keystore the APKs are debug-signed (like the workflow's). For release-signed ones run
`scripts/setup-release-signing.sh` once (creates the keystore in `~/.zairo-signing/` and each app's gitignored
`android/key.properties`; **back that folder up**), then build as above: the output is `<app>-release-signed.apk`.
A phone that has the debug-signed build must uninstall it first (different signature).
On WSL the script also copies the APKs to `Documents\zairo-apk` in your Windows profile (`WIN_APK_DIR=...` changes the
folder, `WIN_COPY=0` turns it off).

### Local checks and the pre-push hook

When Actions is blocked (budget) or you want an answer before pushing: in Ubuntu/WSL run once
`scripts/setup-local-dev-wsl.sh` (JDK 21 + the Flutter version pinned in `flutter-ci.yml`), then
`scripts/verify-local.sh [flutter|backend]`. `scripts/install-git-hooks.sh` (once per clone) enables a `pre-push` hook that
runs the matching checks only for the parts a push touches (apps/packages -> Flutter, backend/ -> backend; docs/scripts
-> nothing). Skip once with `SKIP_VERIFY=1 git push` or `--no-verify`. If flutter/java are missing the hook only warns.
The hook's file classification is tested by `scripts/test-pre-push.sh`.

### When GitHub Actions is not running

If the workflow runs fail within seconds with no steps (billing/spending limit, a disabled workflow) nothing is
checking pull requests. `scripts/verify-local.sh` runs the same checks on your machine — Flutter analyze + test for
every package, and the backend tests (the integration tests need Docker for Testcontainers; without it only the unit
tests run, and the script says so). Fix the cause in GitHub: *Settings → Billing and plans* (Actions minutes /
spending limit) and *Settings → Actions → General* (Actions enabled for this repository, workflows not disabled).

## 2–4. Workflows: what exists, when they run, what they check

### `flutter-ci.yml`

**Triggers:** `pull_request` and `push` on `develop`, `test`, `master`.

**What it does:** a matrix job, one run per Flutter package —
`apps/user_app`, `apps/business_admin`, `apps/platform_admin`, `packages/core_network`,
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
`docker run` rather than a `services:` container so the workflow can
health-check it explicitly before the Gradle build starts.

The image is `bitnamilegacy/minio` pinned to a tag: MinIO stopped
publishing images (`minio/minio` is gone from Docker Hub and
`quay.io/minio/minio` can no longer be pulled), and Bitnami's frozen copy
is the same server. Its entrypoint starts the server itself, so no command
is passed.

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

**`TWOGIS_API_KEY` secret (optional)** — 2GIS is the preferred map for
Kazakhstan. If set (key from the 2GIS Platform Manager, passed as
`--dart-define=TWOGIS_API_KEY`), `user_app` renders a real 2GIS map
(`TwoGisMapsRenderer`, MapGL JS in a WebView — no native setup needed).
Selection order in `maps_providers.dart`: 2GIS key → Google key
(`MAPS_API_KEY` below) → placeholder. On Flutter web the WebView renderer
is skipped. Directions/"open in map" links always default to 2GIS, with
Google Maps as the alternative button.

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

- ~~No deployment of any kind.~~ **Partially done — see §12.** A real,
  free-tier cloud deployment path exists now (Neon Postgres + a
  Docker-based host + S3-compatible object storage) — CI itself still
  doesn't deploy anything itself. The Render service (§12) is created
  manually, but it auto-deploys on its own: Render watches the `test`
  branch of `adatkashov/zairo` (auto-deploy on every commit), so a push to
  `test` — i.e. merging the `develop` → `test` PR — redeploys the backend.
  `develop` and `master` pushes don't trigger a deploy.
- ~~No Docker image build.~~ **Done — `backend/Dockerfile`** (a plain
  multi-stage Dockerfile, not `bootBuildImage`'s Cloud Native Buildpacks —
  see §12 for why: a Docker-runtime image is what every free-tier host in
  §12 actually expects to build from a repo).
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
3. ~~**A real Docker image for `platform-api`**~~ **Done — see §12**
   (`backend/Dockerfile`).
4. ~~**Android release signing**~~ **Done — see §10.**
5. **GitHub Environments for `test` → `staging` → `production`**, each
   with its own secrets and (for `staging`/`production`) a required
   reviewer, once there's an actual place each of those points at. §12's
   Render deployment is that place today, created manually and
   auto-deploying from the `test` branch only (Render's own
   auto-deploy-on-commit, which is what's configured now) — wiring an
   actual deploy GitHub Actions job to it instead is what this item would
   still add.

## 10. Android release signing

A real, Play-Store-eligible release build now exists, kept deliberately
separate from the always-on `build-artifacts.yml` pipeline (see §8's
note): `android-release.yml`, triggered manually
(**Actions → Android Release → Run workflow**, pick `all` or one app).
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

**One shared keystore, three key aliases** — one `ANDROID_KEYSTORE_BASE64`
secret covers all apps; `user_app`, `business_admin` and `platform_admin` each sign with
their own alias inside it, so a compromised/rotated alias for one app
doesn't require touching the other's.

### Required GitHub Secrets

Add these under **repo → Settings → Secrets and variables → Actions → New
repository secret**. All eight are required before `android-release.yml`
can succeed — it checks for them explicitly and fails with a clear
`::error::` naming whichever are missing, rather than an opaque Gradle
signing failure.

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64-encoded, as one line |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore's store password (shared by all aliases) |
| `ANDROID_KEY_ALIAS_USER_APP` | Key alias for `user_app` inside the keystore |
| `ANDROID_KEY_PASSWORD_USER_APP` | That alias's key password |
| `ANDROID_KEY_ALIAS_BUSINESS_ADMIN` | Key alias for `business_admin` inside the keystore |
| `ANDROID_KEY_PASSWORD_BUSINESS_ADMIN` | That alias's key password |
| `ANDROID_KEY_ALIAS_PLATFORM_ADMIN` | Key alias for `platform_admin` inside the keystore |
| `ANDROID_KEY_PASSWORD_PLATFORM_ADMIN` | That alias's key password |

### Generating a keystore from scratch

Only needed once (or if the keystore is ever lost/rotated — see the
warning below). Requires a JDK (`keytool` ships with it). One keystore,
three aliases:

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

keytool -genkeypair -v \
  -keystore zairo-release-upload.jks \
  -storetype JKS \
  -alias platform_admin_upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Zairo Platform Admin, OU=Factory, O=Zairo, L=Almaty, ST=Almaty, C=KZ"
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

## 12. Running the backend in the cloud (no local machine required)

> **Production in Kazakhstan** (all data stored on one VPS in KZ, no foreign storage): see `deploy/kz/README.md`. The section below describes the free test setup (Neon + R2 + Render), which keeps data abroad and is not suitable for real users.

**Current status: deployed and live.** The setup below is running for
real at `https://zairo-backend.onrender.com` (Neon + Cloudflare R2 +
Render, wired exactly as described in this section) — `/actuator/health`
returns `UP`. What follows is both the record of that setup and the
instructions to redo it (a new environment, a different provider, a
rotated credential).

The goal here: nobody's own computer needs to be running Postgres/MinIO/
the backend for the app to work — everything lives in managed, mostly
free-tier cloud services instead. Three pieces, each independently
swappable (the backend reads all of them from plain environment
variables — see `application.yml`, none of this needed a code change
except the `Dockerfile` itself and the `PORT` fallback below):

| Piece | Service (free tier) | Env vars it fills |
|---|---|---|
| Postgres | **Neon** | `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` |
| Object storage (replaces local MinIO) | **Cloudflare R2** (or any S3-compatible provider — `StorageConfig` uses the plain `io.minio` SDK, which speaks the S3 API generically) | `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET` |
| The backend itself | **Render** (or Cloud Run/Fly.io — anything that builds `backend/Dockerfile`) | everything else below |

Redis is deliberately not in this list — nothing in `backend/` connects
to it (see §8's original note); `infrastructure/docker-compose.yml`
provisioning one is for local dev only and has no cloud equivalent to
set up.

### Postgres — Neon

A project already exists (created via the Neon MCP integration): project
`zairo`, database `app_factory`, region `aws-us-east-2`. Its `DB_URL` /
`DB_USERNAME` / `DB_PASSWORD` values were handed to the project owner
directly (not committed here — see the note on secrets below) the same
way the Android keystore was in §10. To create a fresh one instead:
[console.neon.tech](https://console.neon.tech) → New Project → note the
connection string it gives you (use the **non-pooled** host — no
`-pooler` suffix — Flyway's own migration lock doesn't play well with
PgBouncer transaction pooling; Hikari already does the app's own
connection pooling, so Neon's pooler adds nothing here anyway) → append
`?sslmode=require` if it isn't already there.

### Object storage — Cloudflare R2

No MCP/API integration for this in the session that set it up — needs a
few manual clicks in the Cloudflare dashboard:

1. [dash.cloudflare.com](https://dash.cloudflare.com) → sign up/in (free,
   no card required for R2's free tier: 10 GB storage, no egress fees).
2. **R2 Object Storage** (left sidebar) → **Create bucket** → name it
   (the live deployment uses `zairo-media`) → this becomes `MINIO_BUCKET`.
3. **Manage R2 API Tokens** → **Create API Token** → permissions
   **Object Read & Write**, scoped to that one bucket → copy the
   **Access Key ID** (`MINIO_ACCESS_KEY`) and **Secret Access Key**
   (`MINIO_SECRET_KEY`) — the secret is shown once, save it immediately.
4. The bucket's **S3 API** endpoint (shown on the bucket's page) is
   `MINIO_ENDPOINT` — looks like
   `https://<account-id>.r2.cloudflarestorage.com`.

### The backend — Render

Render's MCP tool for creating a web service explicitly only supports
Node/Python/Go/Rust/Ruby/Elixir buildpacks, **not Docker** — and a JVM
app has no non-Docker option there, so this one step is manual (the
dashboard itself has no such limitation):

1. [dashboard.render.com](https://dashboard.render.com) → **New** →
   **Web Service** → connect the `adatkashov/zairo` GitHub repo.
2. **Root Directory**: `backend` (so Render finds `Dockerfile` and the
   build gets the whole Gradle multi-module tree it needs — see the
   Dockerfile's own comment on why).
3. **Runtime/Environment**: **Docker** (Render then just builds
   `backend/Dockerfile` — no other field needed; leave Build/Start
   Command blank, the `Dockerfile` already has both).
4. **Instance Type**: **Free**.
5. **Environment** tab → add every variable from the table above, plus
   `PAYMENT_PROVIDER=mock` (no real Freedom Pay credentials exist yet —
   see ADR-0006) **and `SPRING_PROFILES_ACTIVE=prod`**. Do **not** set
   `SERVER_PORT` — Render injects its own `PORT`, and `application.yml`'s
   `server.port: ${SERVER_PORT:${PORT:8080}}` already falls back to it.

   `SPRING_PROFILES_ACTIVE=prod` turns on `ProductionSecretsValidator`
   (Phase 0 stabilization) — the app refuses to start if `JWT_SECRET`,
   `PLATFORM_ADMIN_JWT_SECRET`, `DB_PASSWORD`, or `MINIO_SECRET_KEY` are
   still the dev-default values committed in `application.yml`, or unset.
   Set every real value from "Where the real values live" below *before*
   adding this variable, or the service will fail to boot.
6. **Branch / auto-deploy**: set **Branch** to `test` and leave
   **Auto-Deploy** on (trigger: *On Commit*). This is how the live
   service `zairo-backend` is configured: only pushes to `test` deploy
   it; `develop` and `master` do not.
7. **Create Web Service.** First build takes a few minutes (full Gradle
   build from scratch, no cache yet). Render gives the service a public
   URL like `https://zairo-backend.onrender.com` once it's live —
   `https://<that-url>/actuator/health` should return `{"status":"UP"}`.

Free-tier caveat: the service **sleeps after 15 minutes idle**, and the
first request after that takes 30–60 seconds to wake it (subsequent
requests are normal speed). Fine for personal use/testing; not
acceptable for a real product with users who'd hit that cold start.

### Pointing the app at it

Same mechanism as physical-device Wi-Fi testing (§10's `api_base_url`
input) — once Render's URL is live, use it instead of a LAN IP:

```
https://zairo-backend.onrender.com/api/v1
```

No code change either way — this was already how the app picks its
backend URL at build time.

### Where the real values live

The actual `DB_PASSWORD`, R2 keys, and freshly generated `JWT_SECRET`/
`PLATFORM_ADMIN_JWT_SECRET` (**not** the ones committed in
`application.yml` — those have been public in git history since early in
the project; see that file's own comment) are never committed here, the
same policy as §10's keystore passwords. They were handed to the
project owner directly when this section was written. Rotate any of
them by generating a new value and updating the one Render env var —
nothing else references them.

## 13. Метрики (Prometheus)

`platform-api` содержит `micrometer-registry-prometheus`, но по умолчанию наружу
отдаются только `health` и `info`. В приложении нет Spring Security, поэтому
`/actuator/prometheus` нельзя открывать на публичном порту. Чтобы собирать метрики:

```
MANAGEMENT_ENDPOINTS_EXPOSE=health,info,prometheus
MANAGEMENT_SERVER_PORT=9090   # внутренний порт, не пробрасывать наружу
```

Prometheus скрейпит `http://<хост>:9090/actuator/prometheus`. Поведение покрыто
тестом `MetricsEndpointApiTests`.
