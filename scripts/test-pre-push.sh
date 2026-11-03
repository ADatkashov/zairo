#!/usr/bin/env bash
# Tests the file classification of scripts/git-hooks/pre-push. Run: scripts/test-pre-push.sh
set -euo pipefail
hook="$(cd "$(dirname "$0")" && pwd)/git-hooks/pre-push"
fail=0
check() { # name, input files, expected output
  local got; got="$(printf '%s\n' "$2" | bash "$hook" --classify | paste -sd, -)"
  if [ "$got" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$got'"; fail=1; fi
}
check "docs only"        $'docs/ci-cd.md\nREADME.md'                 ""
check "scripts only"     $'scripts/verify-local.sh'                 ""
check "flutter app"      $'apps/user_app/lib/main.dart'             "flutter"
check "flutter package"  $'packages/core_ui/lib/a.dart'             "flutter"
check "backend"          $'backend/platform-api/src/A.kt'           "backend"
check "both"             $'apps/user_app/x.dart\nbackend/b.kt'      "flutter,backend"
check "workflows only"   $'.github/workflows/backend-ci.yml'        ""
exit $fail
