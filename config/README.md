# Configuration Structure for Multi-Country Deployment

## Архитектура конфигурации

Система поддерживает единую кодовую базу с конфигурацией по странам. Города хранятся в БД.

```
config/
└── countries/           # Конфиги по странам
    ├── kz.yml          # Казахстан (инфраструктура)
    ├── ru.yml          # Россия (в будущем)
    └── by.yml          # Беларусь (в будущем)
```

## Модель данных

### Countries (страны)
- **Конфиг на уровне страны** (`config/countries/kz.yml`) определяет:
  - База данных (PostgreSQL)
  - Cache (Redis)
  - Object Storage (MinIO)
  - Локализация (языки по умолчанию)
- **Одна инфраструктура на страну** — все города используют одну БД
- **Пример**: `config/countries/kz.yml` — инфра для Казахстана

### Cities (города)
- **Хранятся в БД** в таблице `cities` (не в файлах конфигов!)
- **Параметры города**:
  - `code` — уникальный код (almaty, shymkent и т.д.)
  - `name` — название города
  - `timezone` — часовой пояс
  - `currency` — валюта
  - `latitude`, `longitude` — географические координаты
  - `default_search_radius_km` — радиус поиска по умолчанию
- **Backend** управляет городами через API эндпоинты (`GET /api/cities`)
- **Frontend** получает список доступных городов из API

## Как это работает

### 1. Backend запускается на уровне страны

```bash
# Для Казахстана
./scripts/run-backend.sh kz
```

Backend:
- Читает `config/countries/kz.yml`
- Подключается к БД Казахстана
- Инициализирует таблицу `cities` с начальными городами (если первый запуск)
- Предоставляет API для работы с городами

### 2. Frontend/App запускается с конкретным городом

```bash
# Получить список городов из API
GET /api/cities
→ [{ code: "almaty", name: "Almaty", ... }, { code: "shymkent", ... }]

# Запустить приложение для конкретного города
./scripts/run-app.sh almaty
```

App:
- Получает список доступных городов из API
- Пользователь выбирает город (или город выбирается автоматически)
- Приложение работает с выбранным городом

## Масштабирование на новые города (одна страна)

Для добавления нового города в Казахстане:

### 1. Через Platform Admin интерфейс (для production)

- Открыть Platform Admin панель
- Перейти в **Cities Management**
- Нажать **Add City** и заполнить форму
- Сохранить

Город появится автоматически в API и доступном приложении.

### 2. Для разработки (прямо в БД)

```sql
INSERT INTO cities (id, code, name, country_code, timezone, currency, latitude, longitude, default_search_radius_km)
VALUES (gen_random_uuid(), 'aktau', 'Aktau', 'KZ', 'Asia/Almaty', 'KZT', 43.6577, 51.1694, 50);
```

### 3. Запустить приложение для нового города

```bash
./scripts/run-app.sh aktau
```

**Примечание:** API эндпоинт `POST /api/cities` доступен только для Platform Admin роли (см. auth/PlatformAdminController)

## Масштабирование на новые страны

Когда выходите на новую страну (например, Россию):

1. **Создать конфиг страны** `config/countries/ru.yml`:
   ```yaml
   country:
     code: RU
     name: "Russia"
     timezone: "Europe/Moscow"
     currency: "RUB"

   infrastructure:
     database:
       url: jdbc:postgresql://moscow-db:5432/app_factory_ru
       username: app_factory
       password: app_factory
     
     storage:
       endpoint: https://s3.amazonaws.com
       bucket: factory-media-ru
     
     redis:
       host: moscow-redis
       port: 6379

   localization:
     default-language: ru
     supported-languages:
       - ru
       - en
   ```

2. **Поднять инфраструктуру для России**:
   ```bash
   ./scripts/docker-compose-up.sh ru
   ```

3. **Запустить backend для России**:
   ```bash
   ./scripts/run-backend.sh ru
   ```

4. **Создать города для России** (через API или вручную):
   ```bash
   curl -X POST http://localhost:8080/api/cities \
     -d '{"code": "moscow", "name": "Moscow", "country_code": "RU", ...}'
   ```

5. **Запустить приложение**:
   ```bash
   ./scripts/run-app.sh moscow
   ```

## Environment Variables

Все конфиги поддерживают переопределение через env vars:

```bash
# Переопределить БД для Казахстана
export DB_URL=jdbc:postgresql://prod-db:5432/app_factory_kz
export DB_USERNAME=prod_user
export DB_PASSWORD=prod_pass

# Переопределить MinIO
export MINIO_ENDPOINT=https://s3.prod.com
export MINIO_ACCESS_KEY=prod_key
export MINIO_SECRET_KEY=prod_secret

# Запустить backend с prod инфрой
./scripts/run-backend.sh kz
```

## Структура в БД

```sql
-- Таблица городов (в БД Казахстана)
CREATE TABLE cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(255) NOT NULL UNIQUE,  -- 'almaty', 'shymkent' и т.д.
    name VARCHAR(255) NOT NULL,
    country_code VARCHAR(2) NOT NULL,   -- 'KZ', 'RU', 'BY' и т.д.
    timezone VARCHAR(255),
    currency VARCHAR(3),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    default_search_radius_km INTEGER DEFAULT 50,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Данные в других таблицах привязываются к городу через city_code
ALTER TABLE businesses ADD COLUMN city_code VARCHAR(255);
ALTER TABLE providers ADD COLUMN city_code VARCHAR(255);
ALTER TABLE services ADD COLUMN city_code VARCHAR(255);
ALTER TABLE bookings ADD COLUMN city_code VARCHAR(255);

-- Индексы для быстрого поиска по городу
CREATE INDEX idx_businesses_city ON businesses(city_code);
CREATE INDEX idx_providers_city ON providers(city_code);
CREATE INDEX idx_services_city ON services(city_code);
CREATE INDEX idx_bookings_city ON bookings(city_code);
```

## Текущее состояние

```
🟢 1 Backend Instance → 1 DB (Казахстан)
🟢 Города в таблице cities (Алматы, Шымкент, Алматинская область)
🟢 1 Frontend Instance → выбирает город через UI или API
```

## В будущем (Россия, Беларусь)

```
🟢 Backend KZ → DB KZ (один инстанс на Казахстан)
   └── Города: almaty, shymkent, almaty-region (в таблице cities)

🟢 Backend RU → DB RU (отдельный инстанс на Россию)
   └── Города: moscow, spb, ekaterinburg (в своей таблице cities)

🟢 Backend BY → DB BY (отдельный инстанс на Беларусь)
   └── Города: minsk, grodno (в своей таблице cities)

Фронтенды выбирают город из соответствующей страны через API
```

## Скрипты для управления

Для удобства используйте скрипты:
- `scripts/run-backend.sh COUNTRY [--port PORT]` — запустить backend для страны
- `scripts/run-app.sh CITY` — запустить app для города
- `scripts/docker-compose-up.sh COUNTRY` — поднять инфру для страны

Подробнее в `scripts/README.md`
