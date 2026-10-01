#!/bin/bash

# Run backend for a specific country
# Запуск backend для конкретной страны
#
# Usage: ./scripts/run-backend.sh COUNTRY [OPTIONS]
# Example: ./scripts/run-backend.sh kz
#          ./scripts/run-backend.sh kz --port 8081

set -e

COUNTRY="${1:?Error: COUNTRY argument is required. Usage: ./scripts/run-backend.sh COUNTRY [OPTIONS]}"
shift || true

# Validate country config exists
COUNTRY_CONFIG="config/countries/${COUNTRY}.yml"
if [ ! -f "$COUNTRY_CONFIG" ]; then
    echo "❌ Error: Country config not found: $COUNTRY_CONFIG"
    echo ""
    echo "Available countries:"
    ls -1 config/countries/ 2>/dev/null | sed 's/.yml//' | sed 's/^/  - /' || echo "  No countries configured yet"
    exit 1
fi

# Extract DB config from country config
DB_URL=$(grep -A 5 'database:' "$COUNTRY_CONFIG" | grep 'url:' | sed "s/.*url: //" | sed "s/\${.*://" | sed "s/}.*//" || echo "jdbc:postgresql://localhost:5432/app_factory_${COUNTRY}")

echo "🚀 Starting Factory Backend for country: $COUNTRY"
echo "📁 Using config: $COUNTRY_CONFIG"
echo "🗄️  Database: $DB_URL"
echo ""

# Export country for backend to use
export COUNTRY="${COUNTRY}"

# Change to backend directory
cd "$(dirname "$0")/../backend/platform-api"

# Run with Gradle
echo "▶️  Running: ./gradlew bootRun"
./gradlew bootRun "$@"
