#!/usr/bin/env bash
# Installs a GitHub Actions self-hosted runner for this repo on a Linux x64 machine
# and registers it as a service. Run on the machine that will run CI, as a normal
# (non-root) user with sudo:
#
#   scripts/setup-self-hosted-runner.sh <registration-token>
#
# Token: GitHub -> repo Settings -> Actions -> Runners -> New self-hosted runner
# (valid for 1 hour). Docs: docs/ci-cd.md "Self-hosted runner".
set -euo pipefail

REPO="${REPO:-adatkashov/zairo}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
LABELS="${LABELS:-self-hosted,linux,x64}"
TOKEN="${1:-}"

[ -n "$TOKEN" ] || { echo "usage: $0 <registration-token>" >&2; exit 2; }
[ "$(id -u)" -ne 0 ] || { echo "run as a normal user, not root (the runner refuses root)" >&2; exit 2; }
[ "$(uname -m)" = "x86_64" ] || { echo "this script supports x64 only" >&2; exit 2; }

command -v docker >/dev/null || { echo "Docker is required (backend tests use Testcontainers + MinIO): https://docs.docker.com/engine/install/" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "current user cannot use Docker: sudo usermod -aG docker \$USER, then log in again" >&2; exit 1; }

sudo apt-get update -y
sudo apt-get install -y curl git jq unzip xz-utils zip libicu-dev

version="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
curl -fsSL -o runner.tar.gz "https://github.com/actions/runner/releases/download/v${version}/actions-runner-linux-x64-${version}.tar.gz"
tar xzf runner.tar.gz && rm runner.tar.gz

./config.sh --unattended --replace \
  --url "https://github.com/${REPO}" \
  --token "$TOKEN" \
  --name "$(hostname)-zairo" \
  --labels "$LABELS"

if [ -d /run/systemd/system ]; then
  sudo ./svc.sh install
  sudo ./svc.sh start
else
  # WSL without systemd: no service, run it in a terminal that stays open.
  echo "No systemd (WSL?). Start the runner by hand: cd $RUNNER_DIR && ./run.sh"
fi
echo "Runner installed. Now set the repo variable CI_RUNS_ON to [\"self-hosted\",\"linux\"]"
echo "(Settings -> Secrets and variables -> Actions -> Variables)."
