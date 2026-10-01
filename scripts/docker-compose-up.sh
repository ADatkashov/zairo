#!/bin/bash

# Start infrastructure (Postgres, Redis, MinIO) for a specific country
# Запуск инфраструктуры (Postgres, Redis, MinIO) для конкретной страны
#
# Usage: ./scripts/docker-compose-up.sh COUNTRY [OPTIONS]
# Example: ./scripts/docker-compose-up.sh kz
#          ./scripts/docker-compose-up.sh kz -d
#          ./scripts/docker-compose-up.sh kz down

set -e

COUNTRY="${1:?Error: COUNTRY argument is required. Usage: ./scripts/docker-compose-up.sh COUNTRY [OPTIONS]}"
DOCKER_CMD="${2:-up}"

# Validate country config exists
COUNTRY_CONFIG="config/countries/${COUNTRY}.yml"
if [ ! -f "$COUNTRY_CONFIG" ]; then
    echo "❌ Error: Country config not found: $COUNTRY_CONFIG"
    echo ""
    echo "Available countries:"
    ls -1 config/countries/ 2>/dev/null | sed 's/.yml//' | sed 's/^/  - /' || echo "  No countries configured yet"
    exit 1
fi

# Create infrastructure directory for this country if it doesn't exist
INFRA_DIR="infrastructure/docker-${COUNTRY}"
mkdir -p "$INFRA_DIR"

echo "🚀 Managing infrastructure for country: $COUNTRY"
echo "📁 Infrastructure directory: $INFRA_DIR"
echo ""

# Copy base docker-compose if not exists
if [ ! -f "$INFRA_DIR/docker-compose.yml" ]; then
    echo "📋 Creating docker-compose.yml from template..."
    cat > "$INFRA_DIR/docker-compose.yml" << 'EOF'
services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: app_factory_${COUNTRY}
      POSTGRES_USER: app_factory
      POSTGRES_PASSWORD: app_factory
    ports:
      - "${PG_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app_factory"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: app_factory
      MINIO_ROOT_PASSWORD: app_factory_secret
    ports:
      - "${MINIO_API_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
  minio_data:
EOF
    echo "✅ docker-compose.yml created"
fi

# Create .env file if not exists
if [ ! -f "$INFRA_DIR/.env" ]; then
    echo "📝 Creating .env file..."
    cat > "$INFRA_DIR/.env" << EOF
# Country-specific environment variables
COUNTRY=${COUNTRY}

# Database
PG_PORT=5432
DB_HOST=postgres
DB_PORT=5432
DB_NAME=app_factory_${COUNTRY}
DB_USER=app_factory
DB_PASSWORD=app_factory

# Redis
REDIS_PORT=6379
REDIS_HOST=redis

# MinIO
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_BUCKET=factory-media-${COUNTRY}
MINIO_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=app_factory
MINIO_SECRET_KEY=app_factory_secret
EOF
    echo "✅ .env file created"
fi

echo ""

# Execute docker-compose command
case "$DOCKER_CMD" in
    up)
        echo "▶️  Starting containers..."
        cd "$INFRA_DIR"
        docker-compose --project-name "factory-${COUNTRY}" up -d
        echo ""
        echo "✅ Infrastructure started for $COUNTRY"
        echo ""
        echo "📊 Services:"
        echo "  PostgreSQL: localhost:5432 (user: app_factory, password: app_factory)"
        echo "  Redis:      localhost:6379"
        echo "  MinIO API:  http://localhost:9000"
        echo "  MinIO UI:   http://localhost:9001 (user: app_factory, password: app_factory_secret)"
        echo ""
        ;;
    down)
        echo "⏹️  Stopping containers..."
        cd "$INFRA_DIR"
        docker-compose --project-name "factory-${COUNTRY}" down
        echo "✅ Infrastructure stopped for $COUNTRY"
        ;;
    logs)
        echo "📋 Showing logs..."
        cd "$INFRA_DIR"
        docker-compose --project-name "factory-${COUNTRY}" logs -f
        ;;
    ps)
        echo "📋 Showing container status..."
        cd "$INFRA_DIR"
        docker-compose --project-name "factory-${COUNTRY}" ps
        ;;
    *)
        echo "▶️  Executing: docker-compose $DOCKER_CMD"
        cd "$INFRA_DIR"
        docker-compose --project-name "factory-${COUNTRY}" "$DOCKER_CMD"
        ;;
esac
