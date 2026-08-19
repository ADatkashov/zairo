# app-factory

Монорепозиторий платформы Factory — набора переиспользуемых Flutter +
Spring Boot модулей для быстрой сборки сервисных marketplace-приложений.
Первый vertical — Beauty.

`Factory` — рабочее кодовое имя, не финальный бренд.

Полный план discovery/architecture: `docs/factory-blueprint.md` (или см.
опубликованный артефакт из сессии planning).

## Структура

```
apps/            конечные Flutter-приложения (тонкая сборка поверх packages/)
packages/        Factory Core — переиспользуемые Flutter-пакеты
verticals/       бизнес-логика конкретных отраслей (Beauty, Auto, ...)
backend/         Spring Boot, modular monolith
infrastructure/  docker-compose, CI
docs/adr/        architecture decision records
```

## Flutter workspace

Пакеты в `apps/` и `packages/` связаны обычными path-зависимостями в
`pubspec.yaml` — работают через `flutter pub get` без дополнительных
инструментов. [Melos](https://melos.invertase.dev) (`melos.yaml` в корне)
используется как удобство для запуска команд сразу по всем пакетам:

```
dart pub global activate melos
melos bootstrap
melos run analyze
melos run test
```

## Текущее состояние

- `apps/user_app` — клиентское приложение (бывший `zairo`).
- `packages/core_network` — generic HTTP-клиент (Dio) + сетевые ошибки.
- `packages/core_storage` — secure key/value storage.
- `verticals/`, `backend/`, `infrastructure/` — скелет, наполняются по
  роадмапу (см. Phase 2+).
