#!/bin/bash

# Run Flutter app for a specific city
# Запуск Flutter приложения для конкретного города
#
# Usage: ./scripts/run-app.sh CITY [APP] [OPTIONS]
# Example: ./scripts/run-app.sh almaty
#          ./scripts/run-app.sh shymkent user_app
#          ./scripts/run-app.sh almaty business_admin --release
#
# Note: CITY should exist in the database (api/cities endpoint)

set -e

CITY="${1:?Error: CITY argument is required. Usage: ./scripts/run-app.sh CITY [APP] [OPTIONS]}"
APP="${2:-user_app}"
shift 2 || shift

# Validate app exists
if [ ! -d "apps/$APP" ]; then
    echo "❌ Error: App directory not found: apps/$APP"
    echo ""
    echo "Available apps:"
    ls -1 apps/ 2>/dev/null | sed 's/^/  - /' || echo "  No apps found"
    exit 1
fi

echo "🚀 Starting Flutter App: $APP"
echo "🏙️  City: $CITY"
echo "📱 App will fetch city details from API"
echo ""

# Export city for app to use
export CITY="${CITY}"

# Change to app directory
cd "$(dirname "$0")/../apps/$APP"

# Get Flutter devices
DEVICES=$(flutter devices --output=json 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//' | sed 's/"//' || echo "")

if [ -z "$DEVICES" ]; then
    echo "⚠️  No devices/emulators found. Available options:"
    echo "   1. Start an Android emulator: emulator -avd <avd_name>"
    echo "   2. Connect a physical device"
    echo "   3. Run in Chrome/Web: flutter run -d chrome"
    echo ""
    echo "▶️  Running: flutter run --dart-define CITY=$CITY $@"
    flutter run --dart-define=CITY="$CITY" "$@"
else
    echo "▶️  Running: flutter run -d $DEVICES --dart-define CITY=$CITY $@"
    flutter run -d "$DEVICES" --dart-define=CITY="$CITY" "$@"
fi
