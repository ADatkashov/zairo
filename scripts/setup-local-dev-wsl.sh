#!/usr/bin/env bash
# Installs what scripts/verify-local.sh needs on Ubuntu/Debian (incl. WSL2): JDK 21 and the Flutter SDK pinned in
# .github/workflows/flutter-ci.yml. Safe to re-run. Run as a normal user with sudo:
#
#   scripts/setup-local-dev-wsl.sh
set -euo pipefail

cd "$(dirname "$0")/.."
FLUTTER_VERSION="${FLUTTER_VERSION:-$(sed -n 's/^ *FLUTTER_VERSION: *"\(.*\)"/\1/p' .github/workflows/flutter-ci.yml)}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/development/flutter}"

[ "$(id -u)" -ne 0 ] || { echo "run as a normal user, not root" >&2; exit 2; }
[ -n "$FLUTTER_VERSION" ] || { echo "could not read FLUTTER_VERSION from flutter-ci.yml" >&2; exit 1; }

sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils zip openjdk-21-jdk-headless

if [ -x "$FLUTTER_DIR/bin/flutter" ] && "$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | head -1 | grep -q "Flutter $FLUTTER_VERSION"; then
  echo "Flutter $FLUTTER_VERSION already installed in $FLUTTER_DIR"
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fSL -o "$tmp/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  tar -xJf "$tmp/flutter.tar.xz" -C "$(dirname "$FLUTTER_DIR")"
fi

line="export PATH=\"$FLUTTER_DIR/bin:\$PATH\""
grep -qxF "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
# Git hooks run in non-interactive shells that skip ~/.bashrc; ~/.profile is not enough either, so expose the binary.
sudo ln -sf "$FLUTTER_DIR/bin/flutter" /usr/local/bin/flutter
sudo ln -sf "$FLUTTER_DIR/bin/dart" /usr/local/bin/dart

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
java -version
echo "Done. Open a new terminal (or: source ~/.bashrc), then: scripts/verify-local.sh"
