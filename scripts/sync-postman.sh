#!/usr/bin/env bash
set -euo pipefail

# Regenerates docs/local/Factory API.postman_collection.json from the
# backend's live OpenAPI spec (springdoc's /v3/api-docs), via Postman's
# own official openapi-to-postmanv2 converter. This is a dev-only
# convenience, not part of CI — see docs/ci-cd.md's note on why this
# repo doesn't hand-maintain a static Postman export as a source of
# truth: it drifts from the real API, and the OpenAPI spec (already
# generated on every boot) doesn't.
#
# Prerequisites:
#   - the backend running locally: cd backend && ./gradlew bootRun
#   - Node.js/npm, only so `npx` can fetch-and-run the converter for
#     this one invocation — nothing gets installed globally.
#
# Usage:
#   ./scripts/sync-postman.sh [base-url]
# base-url defaults to http://localhost:8080 (the backend's default
# local port — see backend/platform-api/src/main/resources/application.yml).

BASE_URL="${1:-http://localhost:8080}"
OPENAPI_URL="$BASE_URL/v3/api-docs"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/docs/local"
OUT_FILE="$OUT_DIR/Factory API.postman_collection.json"

TMP_SPEC="$(mktemp -t factory-openapi-XXXXXX.json)"
trap 'rm -f "$TMP_SPEC"' EXIT

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found — install Node.js (https://nodejs.org) first." >&2
  exit 1
fi

echo "Fetching OpenAPI spec from $OPENAPI_URL ..."
if ! curl -sf "$OPENAPI_URL" -o "$TMP_SPEC"; then
  echo "error: could not reach $OPENAPI_URL — is the backend running?" >&2
  echo "  cd backend && ./gradlew bootRun" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Converting to a Postman collection ..."
# --package/binary split on purpose: the npm package is
# "openapi-to-postmanv2" but the CLI it installs is "openapi2postmanv2"
# (no dash) — npx won't reliably guess that pairing on its own.
npx --yes --package=openapi-to-postmanv2 openapi2postmanv2 \
  -s "$TMP_SPEC" -o "$OUT_FILE" -p

echo "Wrote: $OUT_FILE"
