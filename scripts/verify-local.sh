#!/usr/bin/env bash
# Runs what CI runs (.github/workflows/flutter-ci.yml and backend-ci.yml), on this machine — for when GitHub Actions is
# not running (billing, a disabled workflow) or you want an answer before pushing.
#
#   scripts/verify-local.sh                 # everything below
#   scripts/verify-local.sh flutter         # analyze + test every Flutter package
#   scripts/verify-local.sh flutter apps/user_app packages/core_ui   # only those
#   scripts/verify-local.sh backend         # backend unit tests (+ integration tests if Docker is available)
#
# Flutter needs `flutter` on PATH (CI pins 3.47.0). The backend needs JDK 21; its integration tests
# (platform-api) start Postgres through Testcontainers, so they need Docker — without it only the unit tests of every
# module run and the script says so. StorageApiTests need MinIO: the script starts it with Docker (as backend-ci.yml does) and removes it afterwards.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

FLUTTER_PACKAGES=(apps/user_app apps/business_admin apps/platform_admin packages/core_network packages/core_region packages/core_storage packages/core_ui)

failed=()

run_flutter() {
  local packages=("$@")
  [ ${#packages[@]} -eq 0 ] && packages=("${FLUTTER_PACKAGES[@]}")
  command -v flutter >/dev/null || { echo "flutter is not on PATH" >&2; exit 2; }
  for pkg in "${packages[@]}"; do
    echo "=== flutter: $pkg"
    (
      cd "$ROOT/$pkg"
      flutter pub get >/dev/null
      flutter analyze
      # Same tolerance as CI: a package with no test files is skipped, loudly.
      if find test -name '*_test.dart' -type f 2>/dev/null | grep -q .; then
        flutter test
      else
        echo "WARNING: $pkg has no *_test.dart files — flutter test skipped"
      fi
    ) || failed+=("flutter:$pkg")
  done
}

run_backend() {
  command -v java >/dev/null || { echo "java (JDK 21) is not on PATH" >&2; exit 2; }
  echo "=== backend"
  cd "$ROOT/backend"
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    # StorageApiTests need MinIO on :9000 (same image/creds as backend-ci.yml). Started here, removed on exit.
    if ! curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1; then
      docker rm -f minio >/dev/null 2>&1 || true
      docker run -d --name minio -p 9000:9000 -p 9001:9001 \
        -e MINIO_ROOT_USER=app_factory -e MINIO_ROOT_PASSWORD=app_factory_secret \
        bitnamilegacy/minio:2025.7.23-debian-12-r5 >/dev/null
      trap 'docker rm -f minio >/dev/null 2>&1 || true' EXIT
      for _ in $(seq 1 30); do
        curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1 && break
        sleep 1
      done
    fi
    ./gradlew test || failed+=("backend")
  else
    echo "Docker is not available: running the unit tests of every module, skipping platform-api's integration tests."
    ./gradlew test -x :platform-api:test || failed+=("backend")
  fi
  cd "$ROOT"
}

what="${1:-all}"
[ $# -gt 0 ] && shift
case "$what" in
  all) run_flutter; run_backend ;;
  flutter) run_flutter "$@" ;;
  backend) run_backend ;;
  *) echo "usage: $0 [all|flutter [package...]|backend]" >&2; exit 2 ;;
esac

if [ ${#failed[@]} -gt 0 ]; then
  echo
  echo "FAILED: ${failed[*]}"
  exit 1
fi
echo
echo "All checks passed."
