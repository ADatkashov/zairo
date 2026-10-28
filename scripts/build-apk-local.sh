#!/usr/bin/env bash
# Builds installable APKs on this machine — the replacement for build-artifacts.yml (disabled) while GitHub Actions is
# unavailable. Same flags as that workflow. If apps/<app>/android/key.properties exists (scripts/setup-release-signing.sh)
# the APK is release-signed (<app>-release-signed.apk); otherwise debug-signed (<app>-debug-signed.apk).
#
#   scripts/build-apk-local.sh                    # user_app and business_admin
#   scripts/build-apk-local.sh user_app           # one app (user_app | business_admin | platform_admin)
#
# Optional env: API_BASE_URL (default: the live Render backend), MAPS_API_KEY, TWOGIS_API_KEY, OUT_DIR.
# Needs scripts/setup-local-dev-wsl.sh + scripts/setup-android-sdk-wsl.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
API_BASE_URL="${API_BASE_URL:-https://zairo-backend.onrender.com/api/v1}"
OUT_DIR="${OUT_DIR:-$ROOT/build-apk-out}"
apps=("$@"); [ ${#apps[@]} -eq 0 ] && apps=(user_app business_admin)

command -v flutter >/dev/null || { echo "flutter not found: scripts/setup-local-dev-wsl.sh" >&2; exit 2; }
[ -n "${ANDROID_HOME:-}" ] || { echo "ANDROID_HOME not set: scripts/setup-android-sdk-wsl.sh, then open a new terminal" >&2; exit 2; }

mkdir -p "$OUT_DIR"
for app in "${apps[@]}"; do
  case "$app" in user_app|business_admin|platform_admin) ;; *) echo "unknown app: $app" >&2; exit 2;; esac
  echo "=== building $app"
  (
    cd "$ROOT/apps/$app"
    flutter pub get
    MAPS_API_KEY="${MAPS_API_KEY:-}" flutter build apk --release \
      --dart-define=MAPS_API_KEY="${MAPS_API_KEY:-}" \
      --dart-define=TWOGIS_API_KEY="${TWOGIS_API_KEY:-}" \
      --dart-define=API_BASE_URL="$API_BASE_URL"
  )
  if [ -f "$ROOT/apps/$app/android/key.properties" ]; then kind=release-signed; else kind=debug-signed; fi
  cp "$ROOT/apps/$app/build/app/outputs/flutter-apk/app-release.apk" "$OUT_DIR/$app-$kind.apk"
  echo "-> $OUT_DIR/$app-$kind.apk"
done
echo
echo "Done. From Windows open: \\\\wsl\$\\Ubuntu${OUT_DIR}   (or run: explorer.exe \"\$(wslpath -w '$OUT_DIR')\")"
