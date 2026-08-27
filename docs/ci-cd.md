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
  `signingConfigs.getByName("debug")` — there is no release keystore in
  this repo. The APK is real and installable, but it is **debug-signed**,
  not something to hand to the Play Store. See §9.
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

**None exist yet, and none were added by this change.** Every credential
these workflows currently touch (the JWT secrets and MinIO credentials
in `backend/platform-api/src/main/resources/application.yml`) is already
a dev-only value committed in plaintext, by this repo's own explicit
design — see that file's comments ("dev-only secret, fine to commit —
must move to an env var / secrets manager before any real deployment").
CI reuses those same dev values; nothing new needed hardcoding.

When real secrets do show up (a release-signing keystore, a production
JWT secret, a container registry token, a deploy credential), they
belong in **GitHub → Settings → Secrets and variables → Actions**,
referenced as `${{ secrets.NAME }}` — never in a workflow file, a
`.env`, or source. Once real `test`/`staging`/`production` targets
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
- **No release-signed Android build / no AAB.** Play Store submission
  needs a real upload keystore and `signingConfigs.release`, neither of
  which exists. Today's APKs are debug-signed, install-only artifacts
  (see `build-artifacts.yml`'s description above).
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
4. **Android release signing** — generate an upload keystore, store it
   (base64) plus its passwords as repo/environment secrets
   (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` are the conventional
   names), wire `signingConfigs.release` in both apps'
   `android/app/build.gradle.kts`. Only after that does an AAB build
   (for Play Store) become meaningful — building one today would still
   just be debug-signed, same as the current APK.
5. **GitHub Environments for `test` → `staging` → `production`**, each
   with its own secrets and (for `staging`/`production`) a required
   reviewer, once there's an actual place each of those points at. This
   is where the target pipeline's bottom three boxes become real —
   deliberately not built now, per §8.
