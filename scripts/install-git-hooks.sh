#!/usr/bin/env bash
# Points this clone's git at scripts/git-hooks (pre-push runs scripts/verify-local.sh). Run once per clone.
set -euo pipefail
cd "$(dirname "$0")/.."
chmod +x scripts/git-hooks/* scripts/verify-local.sh
git config core.hooksPath scripts/git-hooks
echo "Git hooks enabled for this clone (core.hooksPath=scripts/git-hooks). Undo: git config --unset core.hooksPath"
