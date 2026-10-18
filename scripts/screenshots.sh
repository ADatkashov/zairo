#!/usr/bin/env bash
# Скриншоты всех трёх приложений на живом backend с демо-данными.
#
#   ./scripts/screenshots.sh [выходная_папка]
#
# Что нужно заранее:
#   * запущенный backend на :8080, заполненный scripts/seed-demo-data.sh;
#   * Flutter SDK в PATH; Node.js с модулем playwright (PLAYWRIGHT_MODULE — путь
#     до него, если он не в NODE_PATH) и Chromium (CHROME_PATH, если не стандартный).
# Веб-сборки кладутся в build/screenshots-web/ и раздаются на портах 8101-8103.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build/screenshots}"
WEB="$ROOT/build/screenshots-web"
API="${API_BASE_URL:-http://localhost:8080/api/v1}"

curl -sf "${API%/api/v1}/actuator/health" >/dev/null || { echo "Backend не отвечает на $API"; exit 1; }

port=8101
pids=()
trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT
for app in user_app business_admin platform_admin; do
  (cd "$ROOT/apps/$app" && flutter build web --release --no-web-resources-cdn \
    --dart-define=API_BASE_URL="$API" -o "$WEB/$app")
  python3 -m http.server "$port" -d "$WEB/$app" >/dev/null 2>&1 &
  pids+=($!)
  port=$((port + 1))
done
sleep 2

OUT_DIR="$OUT" node "$ROOT/scripts/screenshots/capture.js" "${2:-all}"
echo "Готово: $OUT"
