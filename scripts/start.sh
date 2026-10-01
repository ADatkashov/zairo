#!/bin/bash

# Main script to start backend infrastructure for a country
# Главный скрипт для запуска backend инфраструктуры для страны
#
# Usage: ./scripts/start.sh COUNTRY [--backend-only|--docker-only]
# Example: ./scripts/start.sh kz
#          ./scripts/start.sh kz --docker-only
#
# Then use ./scripts/run-app.sh CITY to run app for specific city

set -e

COUNTRY="${1:?Error: COUNTRY argument is required. Usage: ./scripts/start.sh COUNTRY [OPTIONS]}"
MODE="${2:-full}"

# Get country config
COUNTRY_CONFIG="config/countries/${COUNTRY}.yml"
if [ ! -f "$COUNTRY_CONFIG" ]; then
    echo "❌ Error: Country config not found: $COUNTRY_CONFIG"
    echo ""
    echo "Available countries:"
    ls -1 config/countries/ 2>/dev/null | sed 's/.yml//' | sed 's/^/  - /' || echo "  No countries configured yet"
    exit 1
fi

COUNTRY_NAME=$(grep "name:" "$COUNTRY_CONFIG" | head -1 | sed "s/.*name: //" | tr -d '"')

echo "════════════════════════════════════════════════════════════════"
echo "🚀 Factory Platform - Multi-Country Startup"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🌍 Country:   $COUNTRY ($COUNTRY_NAME)"
echo "📦 Mode:     $MODE"
echo ""

# Function to show next steps
show_next_steps() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "✅ Backend infrastructure is ready!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "🔗 API Documentation (Swagger):"
    echo "   http://localhost:8080/swagger-ui/index.html"
    echo ""
    echo "📊 MinIO Console:"
    echo "   http://localhost:9001"
    echo "   User: app_factory"
    echo "   Password: app_factory_secret"
    echo ""
    echo "🗄️  PostgreSQL:"
    echo "   Host: localhost:5432"
    echo "   User: app_factory"
    echo "   Database: app_factory_${COUNTRY}"
    echo ""
    echo "📱 To run the Flutter app in another terminal:"
    echo "   ./scripts/run-app.sh CITY [APP]"
    echo ""
    echo "   Examples:"
    echo "   ./scripts/run-app.sh almaty"
    echo "   ./scripts/run-app.sh shymkent business_admin"
    echo ""
}

case "$MODE" in
    --docker-only)
        echo "🐳 Starting Docker infrastructure for $COUNTRY..."
        echo ""
        bash "$(dirname "$0")/docker-compose-up.sh" "$COUNTRY" up
        show_next_steps
        ;;

    --backend-only)
        echo "🐳 Starting Docker infrastructure..."
        bash "$(dirname "$0")/docker-compose-up.sh" "$COUNTRY" up
        echo ""
        sleep 3
        echo ""
        echo "⏳ Waiting for services to be ready..."
        echo ""
        sleep 3
        echo ""
        echo "🔧 Starting Backend for $COUNTRY..."
        bash "$(dirname "$0")/run-backend.sh" "$COUNTRY"
        ;;

    full)
        echo "🐳 Step 1/2: Starting Docker infrastructure..."
        bash "$(dirname "$0")/docker-compose-up.sh" "$COUNTRY" up
        echo ""
        echo "⏳ Waiting for services to be ready..."
        sleep 5
        echo ""

        # Create a background process for backend
        echo "🔧 Step 2/2: Starting Backend..."
        cd "$(dirname "$0")/../backend/platform-api"
        export COUNTRY="$COUNTRY"
        ./gradlew bootRun &
        BACKEND_PID=$!

        # Wait for backend to start
        sleep 10

        # Check if backend started successfully
        if ! ps -p $BACKEND_PID > /dev/null; then
            echo "❌ Backend failed to start"
            exit 1
        fi

        echo ""
        echo "✅ Backend is running (PID: $BACKEND_PID)"
        show_next_steps

        # Keep running until interrupted
        wait $BACKEND_PID
        ;;

    *)
        echo "❌ Unknown mode: $MODE"
        echo ""
        echo "Usage: ./scripts/start.sh COUNTRY [MODE]"
        echo ""
        echo "Modes:"
        echo "  (default/full)   - Start Docker + Backend"
        echo "  --docker-only    - Start only Docker infrastructure"
        echo "  --backend-only   - Start Docker + Backend"
        echo ""
        echo "Then in another terminal, run:"
        echo "  ./scripts/run-app.sh CITY [APP]"
        exit 1
        ;;
esac
