# app-factory

Монорепозиторий платформы Factory — набора переиспользуемых Flutter +
Spring Boot модулей для быстрой сборки сервисных marketplace-приложений.
Первый vertical — Beauty, второй — Auto (оба с реальной функциональностью;
Core остаётся vertical-агностичным).

`Factory` — рабочее кодовое имя, не финальный бренд.

Полный план discovery/architecture: [`docs/factory-blueprint.md`](docs/factory-blueprint.md)
— снапшот опубликованного артефакта "Factory Blueprint" из сессии
planning (2026-08-18/19, Phase 0, до начала кода). Roadmap и границы MVP
в нём отражают состояние на момент написания, не текущий статус — см.
`SESSION_NOTES.md` для актуального прогресса.

## Структура

```
apps/            конечные Flutter-приложения (тонкая сборка поверх packages/);
                 vertical-специфичный UI — в apps/*/lib/features/{beauty,auto}/
packages/        Factory Core — переиспользуемые Flutter-пакеты
verticals/       исторический маркер (см. verticals/README.md) — реальный
                 vertical-код живёт в backend/vertical-*/ и apps/*/lib/features/*/
backend/         Spring Boot, modular monolith; vertical-beauty/vertical-auto —
                 отдельные Gradle-подпроекты, зависят от Core, не наоборот
infrastructure/  docker-compose (локальный Postgres/Redis/MinIO)
.github/         GitHub Actions CI — см. docs/ci-cd.md
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

## CI

Каждый PR и пуш в `develop`/`test`/`master` автоматически проверяются
GitHub Actions: `flutter analyze` + `flutter test` по каждому Flutter-
пакету и `./gradlew build` для backend. Подробности — какие workflow'ы
есть, что именно они проверяют, куда класть секреты и что сознательно
ещё не автоматизировано — в [`docs/ci-cd.md`](docs/ci-cd.md).

## Текущее состояние

- `apps/user_app` — клиентское приложение (бывший `zairo`).
- `apps/business_admin` — приложение для владельцев/модераторов бизнеса
  (салоны и мастерские — обе вертикали, beauty и auto).
- `packages/core_network`, `packages/core_storage`, `packages/core_ui` —
  переиспользуемые Flutter-пакеты Factory Core.
- `backend/` — Spring Boot modular monolith, полноценно построен,
  включая `vertical-beauty` и `vertical-auto`.
- `verticals/` — не используется сборкой, см. `verticals/README.md`.
- `infrastructure/` — скелет/конфиги, наполняются по роадмапу.

## Как открыть в Android Studio

Это монорепо, а не один Flutter-проект — **корень репозитория не
открывать**. Каждое Flutter-приложение открывается как **отдельный,
самостоятельный проект**, указывая на его собственную папку:

```
File → Open → C:\app\zairo\apps\user_app
```

и отдельным окном/инстансом — для второго приложения:

```
File → Open → C:\app\zairo\apps\business_admin
```

Если открыть корень `C:\app\zairo\` напрямую, Android Studio не находит
ни `pubspec.yaml`, ни настоящий Gradle/Android-проект на этом уровне —
структура проекта окажется пустой, а Flutter/Android run-конфигурации
не появятся. Если это уже произошло и `.idea/` в корне репозитория
выглядит "пустым" или предлагает несуществующий Gradle-модуль — можно
безопасно удалить `.idea/` в корне (он никогда не хранится в git) и
открыть заново по инструкции выше.

`packages/*` не открываются отдельно — они подключены через
`path:`-зависимости в `pubspec.yaml` каждого приложения и появляются в
Project-панели автоматически при открытии `apps/user_app` или
`apps/business_admin`.
