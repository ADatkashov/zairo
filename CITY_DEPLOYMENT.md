# Multi-Country Deployment - Quick Start

Инструкция по запуску системы для разных стран и городов.

## TL;DR — Суперыстрый старт

```bash
# Для Казахстана
./scripts/run-backend.sh kz        # Запустить backend
./scripts/run-app.sh almaty        # Запустить app для Алматы

# Для другого города в Казахстане
./scripts/run-app.sh shymkent
```

Это запустит: Docker (Postgres, Redis, MinIO) + Backend + Flutter app.

## Детальный старт

### Шаг 1: Инфраструктура (один раз для всей страны)

```bash
# Запустить Docker контейнеры для Казахстана
./scripts/docker-compose-up.sh kz

# Проверить, что всё работает
docker ps | grep factory
```

**Проверка:**
- PostgreSQL: `psql -h localhost -U app_factory -d app_factory_kz`
- Redis: `redis-cli ping` → должна вернуть `PONG`
- MinIO: http://localhost:9001 (user: `app_factory`, password: `app_factory_secret`)

### Шаг 2: Backend (один раз для страны)

```bash
# Терминал 2
./scripts/run-backend.sh kz
```

**Проверка:**
- API: http://localhost:8080/swagger-ui/index.html
- Health: http://localhost:8080/actuator/health
- Доступные города: http://localhost:8080/api/cities

### Шаг 3: Frontend (для конкретного города)

```bash
# Терминал 3 - Алматы
./scripts/run-app.sh almaty

# или Шымкент (в другом терминале)
./scripts/run-app.sh shymkent

# или Business Admin для Алматы
./scripts/run-app.sh almaty business_admin
```

## Доступные города в Казахстане

Backend автоматически инициализирует города из БД:
- **almaty** — Алматы (43.238°, 77.064°)
- **almaty-region** — Алматинская область (45.000°, 77.500°)
- **shymkent** — Шымкент (42.309°, 69.596°)

Получить полный список:
```bash
curl http://localhost:8080/api/cities
```

## Добавить новый город в Казахстан

### Вариант 1: Через API

```bash
curl -X POST http://localhost:8080/api/cities \
  -H "Content-Type: application/json" \
  -d '{
    "code": "aktau",
    "name": "Aktau",
    "country_code": "KZ",
    "timezone": "Asia/Almaty",
    "currency": "KZT",
    "latitude": 43.6577,
    "longitude": 51.1694,
    "default_search_radius_km": 50
  }'
```

### Вариант 2: Вручную в PostgreSQL

```sql
psql -h localhost -U app_factory -d app_factory_kz

INSERT INTO cities (code, name, country_code, timezone, currency, latitude, longitude, default_search_radius_km)
VALUES ('aktau', 'Aktau', 'KZ', 'Asia/Almaty', 'KZT', 43.6577, 51.1694, 50);
```

### Запустить приложение для нового города

```bash
./scripts/run-app.sh aktau
```

## Добавить новую страну (Россия)

### 1. Создать конфиг страны

```bash
cat > config/countries/ru.yml << 'EOF'
country:
  code: RU
  name: "Russia"
  timezone: "Europe/Moscow"
  currency: "RUB"

infrastructure:
  database:
    url: jdbc:postgresql://localhost:5433/app_factory_ru
    username: app_factory
    password: app_factory
  
  storage:
    endpoint: http://localhost:9000
    bucket: factory-media-ru
  
  redis:
    host: localhost
    port: 6379

localization:
  default-language: ru
  supported-languages:
    - ru
    - en
EOF
```

### 2. Поднять инфру для России

```bash
./scripts/docker-compose-up.sh ru

# Или с другим портом PostgreSQL
PG_PORT=5433 ./scripts/docker-compose-up.sh ru
```

### 3. Запустить backend для России

```bash
./scripts/run-backend.sh ru
```

### 4. Создать города для России

```bash
# Москва
curl -X POST http://localhost:8080/api/cities \
  -H "Content-Type: application/json" \
  -d '{
    "code": "moscow",
    "name": "Moscow",
    "country_code": "RU",
    "timezone": "Europe/Moscow",
    "currency": "RUB",
    "latitude": 55.7558,
    "longitude": 37.6173,
    "default_search_radius_km": 50
  }'

# Санкт-Петербург
curl -X POST http://localhost:8080/api/cities \
  -H "Content-Type: application/json" \
  -d '{
    "code": "spb",
    "name": "Saint Petersburg",
    "country_code": "RU",
    "timezone": "Europe/Moscow",
    "currency": "RUB",
    "latitude": 59.9311,
    "longitude": 30.3609,
    "default_search_radius_km": 50
  }'
```

### 5. Запустить приложение для России

```bash
./scripts/run-app.sh moscow
./scripts/run-app.sh spb
```

## Контроль сервисов

### Просмотр статуса

```bash
# Для Казахстана
./scripts/docker-compose-up.sh kz ps

# Логи PostgreSQL Казахстана
./scripts/docker-compose-up.sh kz logs postgres

# Логи всех сервисов
./scripts/docker-compose-up.sh kz logs -f
```

### Остановить инфру

```bash
./scripts/docker-compose-up.sh kz down

# С удалением данных
./scripts/docker-compose-up.sh kz down -v
```

## Полезные URL

| Сервис | URL | Учетные данные |
|--------|-----|---|
| Swagger UI (API) | http://localhost:8080/swagger-ui/index.html | - |
| MinIO Console | http://localhost:9001 | app_factory / app_factory_secret |
| PostgreSQL (KZ) | localhost:5432 | app_factory / app_factory |
| Redis | localhost:6379 | - |

## Troubleshooting

### Port уже занят

```bash
# Найти процесс
lsof -i :8080

# Убить процесс
kill -9 <PID>

# Или использовать другой port для backend
./scripts/run-backend.sh kz --args='--server.port=8081'
```

### PostgreSQL не запускается

```bash
# Проверить логи
./scripts/docker-compose-up.sh kz logs postgres

# Очистить и пересоздать
./scripts/docker-compose-up.sh kz down -v
./scripts/docker-compose-up.sh kz up
```

### Flutter не видит app

```bash
# Проверить устройства
flutter devices

# Если нет - запустить эмулятор
emulator -avd Pixel_5_API_30

# или Chrome
flutter run -d chrome
```

## Структура папок

```
config/
└── countries/                  # Конфиги стран (инфраструктура)
    └── kz.yml                 # Казахстан
    # Будущие:
    # └── ru.yml               # Россия
    # └── by.yml               # Беларусь

infrastructure/
├── docker-kz/                  # Инфра для Казахстана
│   ├── docker-compose.yml
│   ├── .env
│   └── [volumes]/
│
# Будущие страны:
├── docker-ru/                  # Инфра для России
└── docker-by/                  # Инфра для Беларуси

database/
└── cities/                     # Города хранятся в БД
    # (не в файлах конфигов!)
    # SELECT * FROM cities; → список городов

scripts/
├── start.sh                    # [DEPRECATED] для полного старта
├── run-backend.sh             # Запустить backend для страны
├── run-app.sh                 # Запустить app для города
└── docker-compose-up.sh       # Управление Docker для страны
```

## Дополнительная информация

- 📖 Полная документация: [config/README.md](config/README.md)
- 🔧 Интеграция с кодом: [docs/city-configuration-integration.md](docs/city-configuration-integration.md)
- 📜 Скрипты: [scripts/README.md](scripts/README.md)

---

**Вопросы?** Проверьте логи и документацию выше!
