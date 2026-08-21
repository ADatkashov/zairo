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
- `apps/business_admin` — приложение для владельцев/модераторов салонов.
- `packages/core_network`, `packages/core_storage`, `packages/core_ui` —
  переиспользуемые Flutter-пакеты Factory Core.
- `backend/` — Spring Boot modular monolith, полноценно построен.
- `verticals/`, `infrastructure/` — скелет/конфиги, наполняются по
  роадмапу.

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
