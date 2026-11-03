#!/usr/bin/env bash
# Installs the Android SDK command-line tools on Ubuntu/WSL so `flutter build apk` works (scripts/build-apk-local.sh).
# Run after scripts/setup-local-dev-wsl.sh (needs Flutter + JDK 21). Safe to re-run.
#
#   scripts/setup-android-sdk-wsl.sh
#
# Build-tools / platform packages that Gradle needs (compileSdk 37 ...) are downloaded by the Android Gradle plugin on
# the first build, once the licenses are accepted here.
set -euo pipefail

SDK_DIR="${ANDROID_HOME:-$HOME/Android/Sdk}"
CMDLINE_VERSION="${CMDLINE_VERSION:-11076708}"

[ "$(id -u)" -ne 0 ] || { echo "run as a normal user, not root" >&2; exit 2; }
command -v flutter >/dev/null || { echo "flutter not found: run scripts/setup-local-dev-wsl.sh first" >&2; exit 1; }
command -v java >/dev/null || { echo "java not found: run scripts/setup-local-dev-wsl.sh first" >&2; exit 1; }
sudo apt-get install -y unzip curl >/dev/null

if [ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  curl -fSL -o "$tmp/cmdline.zip" "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VERSION}_latest.zip"
  mkdir -p "$SDK_DIR/cmdline-tools"
  unzip -q "$tmp/cmdline.zip" -d "$tmp"
  rm -rf "$SDK_DIR/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
fi

export ANDROID_HOME="$SDK_DIR"
export PATH="$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$PATH"
yes | sdkmanager --licenses >/dev/null || true
sdkmanager "platform-tools"

for line in "export ANDROID_HOME=\"$SDK_DIR\"" "export PATH=\"\$ANDROID_HOME/platform-tools:\$PATH\""; do
  grep -qxF "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
done
flutter config --android-sdk "$SDK_DIR" >/dev/null
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
echo "Android SDK ready in $SDK_DIR. Next: scripts/build-apk-local.sh user_app"
