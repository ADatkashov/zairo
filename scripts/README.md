# Deployment Scripts for Multi-City Platform

Удобные скрипты для запуска Factory Platform на разные города и страны.

## Быстрый старт

### Запустить инфру + backend для Казахстана:
```bash
chmod +x scripts/*.sh
./scripts/start.sh kz
```

### Запустить приложение для конкретного города (в другом терминале):
```bash
./scripts/run-app.sh almaty

# или для другого города
./scripts/run-app.sh shymkent
```

## Проверка перед пушем

`./scripts/verify-local.sh` — те же проверки, что в CI (Flutter analyze + test по всем пакетам и тесты бэкенда), локально.
Нужен, когда GitHub Actions не запускается. Подробности: `docs/ci-cd.md`.

## Доступные скрипты

### 1. `start.sh` — Главный скрипт
Запускает всё необходимое для конкретного города

```bash
# Полный запуск (Docker + Backend + Frontend)
./scripts/start.sh almaty

# Только инфраструктура (Docker)
./scripts/start.sh almaty --docker-only

# Docker + Backend (для ручного тестирования фронтенда)
./scripts/start.sh almaty --backend-only

# Только фронтенд (если инфра уже запущена)
./scripts/start.sh almaty --frontend-only
```

### 2. `docker-compose-up.sh` — Управление инфраструктурой
Запускает/останавливает Docker контейнеры (PostgreSQL, Redis, MinIO)

```bash
# Запустить инфру для Казахстана
./scripts/docker-compose-up.sh kz

# Остановить инфру
./scripts/docker-compose-up.sh kz down

# Показать статус
./scripts/docker-compose-up.sh kz ps

# Показать логи
./scripts/docker-compose-up.sh kz logs

# Запустить инфру для России (в будущем)
./scripts/docker-compose-up.sh ru
```

**Что создаёт скрипт:**
- Директория `infrastructure/docker-kz/` со своим `docker-compose.yml`
- Файл `.env` с конфигурацией
- Отдельные volumes для данных каждой страны

**Доступные сервисы:**
- PostgreSQL на порту 5432
- Redis на порту 6379
- MinIO API на порту 9000
- MinIO Console на порту 9001

### 3. `run-backend.sh` — Запуск бэкенда
Запускает Spring Boot приложение для конкретной страны

```bash
# Запустить backend для Казахстана
./scripts/run-backend.sh kz

# С дополнительными Gradle опциями
./scripts/run-backend.sh kz --args='--spring.profiles.active=prod'

# На другом порту
./scripts/run-backend.sh kz --args='--server.port=8081'
```

### 4. `run-app.sh` — Запуск Flutter приложения
Запускает Flutter приложение для конкретного города

```bash
# Запустить user app для Алматы (по умолчанию)
./scripts/run-app.sh almaty

# Запустить business admin для Шымкента
./scripts/run-app.sh shymkent business_admin

# Release версию
./scripts/run-app.sh almaty user_app --release

# В Chrome
./scripts/run-app.sh almaty user_app -d chrome
```

## Типичные сценарии

### Сценарий 1: Локальная разработка Алматы

```bash
# Терминал 1: Запустить все
./scripts/start.sh almaty

# Терминал 2 (пока первый работает): Горячая загрузка фронтенда
cd apps/user_app
flutter run --dart-define=CITY=almaty
```

### Сценарий 2: Тестирование разных городов одновременно

```bash
# Терминал 1: Docker для всех городов (они используют одну инфру)
./scripts/docker-compose-up.sh kz

# Терминал 2: Backend для Казахстана
./scripts/run-backend.sh kz

# Терминал 3: Frontend для Алматы
./scripts/run-app.sh almaty

# Терминал 4: Frontend для Шымкента
./scripts/run-app.sh shymkent
```

### Сценарий 3: Добавить новый город

**Требуется роль Platform Admin**

```bash
# 1. Запустить backend для Казахстана (если не запущен)
./scripts/start.sh kz

# 2. Открыть Platform Admin интерфейс и добавить город:
#    - City Code: aktau
#    - City Name: Aktau
#    - Country: KZ
#    - Timezone: Asia/Almaty
#    - Currency: KZT
#    - Latitude: 43.6577
#    - Longitude: 51.1694

# 3. Запустить приложение для нового города
./scripts/run-app.sh aktau
```

**Или для разработки (вручную в БД):**
```bash
psql -h localhost -U app_factory -d app_factory_kz
INSERT INTO cities (code, name, country_code, timezone, currency, latitude, longitude, default_search_radius_km)
VALUES ('aktau', 'Aktau', 'KZ', 'Asia/Almaty', 'KZT', 43.6577, 51.1694, 50);
```

### Сценарий 4: Выход на новую страну (Россия)

```bash
# 1. Создать конфиг страны со своей инфраструктурой
cat > config/countries/ru.yml << 'EOF'
country:
  code: RU
  infrastructure:
    database:
      url: jdbc:postgresql://prod-db-ru:5432/app_factory_ru
    storage:
      bucket: factory-media-ru
  cities:
    - moscow
    - spb
EOF

# 2. Создать города
cat > config/cities/moscow.yml << 'EOF'
app:
  city:
    code: moscow
    name: "Moscow"
    country: "RU"
    latitude: 55.7558
    longitude: 37.6173
EOF

# 3. Запустить инфру для России
./scripts/docker-compose-up.sh ru up

# 4. Запустить backend для России (если своя инфра)
./scripts/run-backend.sh ru

# 5. Запустить приложение для Москвы
./scripts/run-app.sh moscow
```

## Environment Variables

Все скрипты поддерживают переопределение через env vars:

```bash
# PostgreSQL
export DB_URL=jdbc:postgresql://custom-host:5432/app_factory_kz
export DB_USERNAME=custom_user
export DB_PASSWORD=custom_pass

# MinIO/S3
export MINIO_ENDPOINT=https://s3.amazonaws.com
export MINIO_ACCESS_KEY=your_key
export MINIO_SECRET_KEY=your_secret

# Backend port
export SERVER_PORT=8081

# Запустить backend с кастомными переменными
./scripts/run-backend.sh kz
```

## Troubleshooting

### Port уже занят
```bash
# Найти процесс на порту 5432
lsof -i :5432

# Убить процесс
kill -9 <PID>

# Или запустить на другом порту
PG_PORT=5433 ./scripts/docker-compose-up.sh kz
```

### Backend не подключается к БД
```bash
# Проверить, что Docker контейнеры запущены
docker ps | grep factory

# Посмотреть логи PostgreSQL
./scripts/docker-compose-up.sh kz logs postgres

# Переподключиться
./scripts/docker-compose-up.sh kz down
./scripts/docker-compose-up.sh kz up
```

### Flutter не видит приложение
```bash
# Убедиться, что есть устройство/эмулятор
flutter devices

# Запустить эмулятор
emulator -avd Pixel_5_API_30

# Перезагрузить pubspec
flutter pub get

# Запустить приложение
./scripts/run-app.sh almaty
```

## Структура создаваемых файлов

```
infrastructure/
├── docker-kz/
│   ├── docker-compose.yml
│   ├── .env
│   └── [postgres_data, redis_data, minio_data]/

# В будущем:
├── docker-ru/
│   ├── docker-compose.yml
│   └── .env
└── docker-by/
    ├── docker-compose.yml
    └── .env
```

## Notes

- **Одна инфра на страну**: Все города Казахстана используют одну БД, Redis, MinIO
- **Фронтенд = город**: Приложение запускается с конкретным городом через `--dart-define=CITY=xxx`
- **Backend = страна**: Backend запускается на уровне страны и управляет всеми её городами
- **Масштабируемость**: Для новой страны просто создайте `countries/xx.yml` и свою инфру

## Дальнейшие улучшения

- [ ] Поддержка health checks для сервисов
- [ ] Автоматическое создание DB схемы/миграций
- [ ] Docker образ для backend (вместо Gradle)
- [ ] Docker образ для Flutter app
- [ ] Kubernetes манифесты для production
- [ ] CI/CD для deploy по городам
