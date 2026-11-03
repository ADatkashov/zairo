#!/usr/bin/env bash
# Creates a release keystore (one file, three aliases) OUTSIDE the repo and writes apps/*/android/key.properties
# (gitignored) so scripts/build-apk-local.sh produces release-signed APKs. Run once. Details: docs/ci-cd.md §10.
#
#   scripts/setup-release-signing.sh
#
# The keystore and passwords.txt land in ~/.zairo-signing/ (chmod 600). BACK THEM UP somewhere safe outside this
# machine (password manager / encrypted drive): if the keystore is lost you can never ship an update that installs over
# apps signed with it, and the Play Store ties an app to its upload key forever.
set -euo pipefail

cd "$(dirname "$0")/.."
DIR="${SIGNING_DIR:-$HOME/.zairo-signing}"
STORE="$DIR/zairo-release-upload.jks"
command -v keytool >/dev/null || { echo "keytool not found: scripts/setup-local-dev-wsl.sh (JDK 21)" >&2; exit 2; }

if [ -e "$STORE" ]; then
  echo "Keystore already exists: $STORE (not overwritten). Only rewriting key.properties."
  [ -f "$DIR/passwords.txt" ] || { echo "passwords.txt missing in $DIR: cannot rebuild key.properties" >&2; exit 1; }
  # shellcheck disable=SC1090
  . "$DIR/passwords.txt"
else
  mkdir -p "$DIR"; chmod 700 "$DIR"
  PASSWORD="$(head -c 24 /dev/urandom | base64 | tr -d '/+=\n' | head -c 24)"
  for app in user_app business_admin platform_admin; do
    keytool -genkeypair -noprompt -keystore "$STORE" -storetype PKCS12 \
      -storepass "$PASSWORD" -keypass "$PASSWORD" -alias "${app}_upload" \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Zairo ${app}, OU=Factory, O=Zairo, L=Almaty, ST=Almaty, C=KZ" >/dev/null 2>&1
  done
  printf 'PASSWORD=%s\n' "$PASSWORD" > "$DIR/passwords.txt"
  chmod 600 "$STORE" "$DIR/passwords.txt"
fi

for app in user_app business_admin platform_admin; do
  umask 077
  cat > "apps/$app/android/key.properties" <<PROPS
storeFile=$STORE
storePassword=$PASSWORD
keyAlias=${app}_upload
keyPassword=$PASSWORD
PROPS
done

echo
echo "Done. Keystore: $STORE"
echo "Passwords:     $DIR/passwords.txt"
echo "BACK THESE TWO FILES UP now (e.g. copy to Windows: cp -r $DIR /mnt/c/Users/<you>/Documents/zairo-signing)."
echo "Next: scripts/build-apk-local.sh user_app business_admin platform_admin"
