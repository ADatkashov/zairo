# Factory Blueprint

*Product discovery & architecture plan · черновик v0.1 · Phase 0 — Discovery · 2026-08-19 · первый vertical: Beauty*

> «Factory» — рабочее кодовое имя платформы, не финальный бренд. Финальное
> название не предлагается и не фиксируется в этом документе.

> Скопировано из опубликованного артефакта "Factory Blueprint"
> (https://claude.ai/code/artifact/59a49cef-f047-488c-a251-551087c40a58,
> приватный) в репозиторий как статичный снапшот на момент 2026-08-25 —
> planning-сессия сама по себе не обновляется вместе с кодом. Раздел
> "Roadmap" (§14) и границы MVP (§6–7) отражают состояние на момент
> написания документа (Phase 0, до начала кода) — по факту на 2026-08-25
> Beauty и Auto оба уже реализованы с реальной функциональностью (см.
> `SESSION_NOTES.md`, `docs/erd/core-domain.md`), значительно дальше, чем
> здесь описано.

Платформа для сборки сервисных marketplace-приложений из переиспользуемых
модулей. Первый vertical — Beauty. Ниже — план продуктового discovery и
архитектуры, до написания кода.

## Оглавление

**Концепция**
1. [Концепция Factory](#01-концепция-factory)
2. [Монорепозиторий](#02-структура-монорепозитория)
3. [Core / Marketplace / Vertical](#03-core--marketplace--vertical)
4. [Generic-модули](#04-generic-модули-factory)
5. [Beauty-модули](#05-beauty-модули-vertical)

**Границы MVP**
6. [Что входит в MVP](#06-что-входит-в-mvp)
7. [Что не входит в MVP](#07-что-не-входит-в-mvp)

**Архитектура**
8. [Backend](#08-backend-архитектура)
9. [База данных](#09-база-данных)
10. [Flutter](#10-flutter-архитектура)
11. [Business Admin](#11-business-admin)
12. [Безопасность](#12-безопасность)
13. [Deployment](#13-deployment)

**Путь вперёд**
14. [Roadmap](#14-roadmap)
15. [Auto без изменения Core](#15-как-добавить-auto-без-изменения-core)
16. [Dental без изменения Core](#16-как-добавить-dental-без-изменения-core)
17. [Монетизация](#17-монетизация)
18. [MVP → Production](#18-mvp--production)
19. [Чего не делать сейчас](#19-чего-не-делать-сейчас)
20. [Первые задачи](#20-первые-конкретные-задачи)

---

## 01 / Концепция Factory

Factory — это не приложение, а способ быстро собирать marketplace-приложения
для сервисных отраслей из общего набора модулей.

```
Factory (Core) + Vertical-модули = Новый marketplace
```

Beauty — первый vertical, но не единственная причина существования Factory.
Формула должна одинаково работать для Auto, Home Services, Dental — иначе
Factory не платформа, а просто Beauty-приложение с общим названием пакетов.

> **⚠ Ключевой риск (на момент написания)**
> На старте у нас есть только один vertical — Beauty. Мы физически не можем
> знать, что «универсально», а что «просто оказалось так в Beauty», пока не
> построим второй vertical. Любая абстракция, придуманная сейчас без
> второго примера — это догадка.

Поэтому рекомендуемый подход — **vertical-first, extract-second**: в фазах
1–4 мы строим Beauty конкретно, но дисциплинированно раскладываем код по
границам будущих пакетов Factory (см. §3). Формальное «затвердевание»
контракта Core ↔ Vertical происходит в Phase 9, когда строится Auto — это и
есть KPI: если Auto собирается быстрее, границы угаданы верно.

## 02 / Структура монорепозитория

Один монорепозиторий на старте: разделять на отдельные репозитории раньше
времени — накладные расходы без выгоды при команде из нескольких человек.

```
app-factory/
├── apps/                      # конечные приложения — тонкий слой сборки
│   ├── user_app/              # Flutter, клиент маркетплейса
│   └── business_admin/        # Flutter, кабинет бизнеса
│
├── packages/                  # Factory Core — Dart/Flutter, управляется Melos
│   ├── core_network/
│   ├── core_ui/
│   ├── core_storage/
│   ├── localization/
│   ├── auth/
│   ├── profile/
│   ├── permissions/
│   ├── search/
│   ├── maps/
│   ├── booking/
│   ├── payments/
│   ├── reviews_ratings/
│   ├── favorites/
│   ├── push_notifications/
│   ├── chat/
│   ├── analytics/
│   ├── file_storage/
│   ├── onboarding/
│   └── feature_flags/
│
├── verticals/
│   └── beauty/
│       ├── beauty_flutter/    # salons, masters, portfolio, экраны
│       └── beauty_backend/    # beauty-specific правила бронирования
│
├── backend/                   # Spring Boot, Gradle multi-module, один деплой-юнит
│   ├── platform-api/          # сборочный модуль (main), REST-контроллеры, DI-провод
│   ├── auth/
│   ├── users/
│   ├── providers/
│   ├── services/
│   ├── booking/
│   ├── payments/
│   ├── reviews/
│   ├── notifications/
│   ├── search/
│   └── vertical-beauty/       # зеркало verticals/beauty на бэкенде
│
├── infrastructure/
│   ├── docker-compose.yml     # postgres, redis, minio(S3), backend — локальная разработка
│   └── ci/
│
└── docs/
    └── adr/                   # architecture decision records
```

**Инструменты:** Melos для Flutter-workspace (единый `pub get`/версионирование
пакетов), Gradle multi-module для backend с явными границами модулей по
bounded context. Оба инструмента дают «монорепо ощущается как один проект»,
не жертвуя модульностью.

> **Открытый вопрос на момент написания**
> Текущий репозиторий `zairo` — это будущий корень `app-factory`, или
> отдельный самостоятельный проект? В `zairo/lib/core/` уже есть `network`,
> `storage` на Riverpod + Dio + flutter_secure_storage — готовая заготовка
> под `core_network` / `core_storage`. *(Решено: `zairo` стал корнем
> `app-factory` — см. текущую структуру репозитория и `README.md`.)*

## 03 / Core / Marketplace / Vertical

Не два слоя, а три. Разница между «Core» и «Marketplace Engine» важна:
технический фундамент не должен знать, что такое бронирование, а
бронирование не должно знать, что такое салон.

| Layer | Знает про | Содержит |
|---|---|---|
| **Layer 2 — Vertical** (Beauty, Auto, Dental…) | Конкретную отрасль | Салон, мастер, портфолио, правила записи на окрашивание |
| **Layer 1 — Marketplace Engine** | Маркетплейс, не отрасль | Provider, Service, Booking, Availability, TimeSlot, Payment, Review, Search |
| **Layer 0 — Platform Core** | Ничего про маркетплейс | auth, permissions, profile, notifications, files, localization, analytics, config |

Механизм подключения vertical к Layer 1 — не `if (vertical == beauty)`
внутри Core, а vertical *реализует* интерфейсы, которые определяет Core:

- `Bookable`, `AvailabilityProvider`, `PricingStrategy` — vertical
  подставляет свою реализацию.
- `Provider` и `Service` имеют универсальные поля + `vertical_code` + JSONB
  `attributes` для отраслевых данных без миграций на каждый vertical.
- Vertical регистрирует свою таксономию категорий, экраны и правила через
  DI, а не патчит Core.

Это прямое воплощение принципа: Core не должен содержать
`if Beauty / if Auto`.

*(По факту реализации: `Provider.vertical` — простая opaque-строка, не
JSONB `attributes` — см. `docs/erd/core-domain.md`. Механизм подключения —
не DI-интерфейсы вроде `Bookable`, а отдельные Gradle-модули
(`vertical-beauty`, `vertical-auto`), зависящие *от* Core-модулей и
использующие их сервисы напрямую. Тот же принцип "Core не знает про
vertical", другая, более простая для monolith'а реализация.)*

## 04 / Generic-модули Factory

Сгруппированы по назначению, а не по алфавиту — так виднее, какие модули
зависят друг от друга.

- **Identity & Access** — `auth`, `profile`, `permissions`
- **Discovery** — `search`, `maps`, `categories/taxonomy`
- **Commerce Engine** — `booking`, `availability`, `payments`
- **Trust** — `reviews`, `ratings`, `favorites`
- **Engagement** — `push_notifications`, in-app notifications, `chat`
- **Platform** — `analytics`, `file_storage`, `localization`, `onboarding`,
  admin-shell, `feature_flags` / config

## 05 / Beauty-модули (vertical)

| Модуль | Что делает |
|---|---|
| `salons` | Профиль салона, филиалы, часы работы, галерея. |
| `masters` | Мастер как отдельный Provider внутри салона или независимо. |
| `beauty_services` | Каталог услуг (окрашивание, маникюр…) поверх generic Service. |
| `portfolio` | До/после, фото работ мастера. |
| `beauty_booking_rules` | Длительность по типу услуги, буфер между записями, привязка мастера к слоту. |

> **⚠ Пограничный случай, который стоило держать в уме**
> `portfolio` — кандидат на то, чтобы позже стать generic «Provider Media
> Gallery» в Core (Auto-мастеру тоже полезно показать фото ремонта, Dental
> — фото до/после). Не переносить сразу — именно такие случаи и должны
> накапливаться до Phase 9, чтобы решение об извлечении в Core
> принималось на фактах, а не заранее. *(По факту: остался
> vertical-specific — `Master.photoUrl`/`beauty_portfolio_item` в
> vertical-beauty, `Mechanic.photoUrl` без отдельной галереи в
> vertical-auto — портфолио-галерея не запрашивалась для auto, extraction
# в Core не понадобился.)*

## 06 / Что входит в MVP

Один город, один vertical (Beauty), один платёжный провайдер, User App
полнее, чем Business Admin.

- User App: поиск по услуге/фильтрам, карточка провайдера (рейтинг,
  отзывы, портфолио, цена), реальные свободные слоты, booking, депозит,
  push-уведомления, отзыв после визита.
- Business Admin (минимум): профиль бизнеса, услуги, расписание, список
  записей.
- Deterministic ranking — rating, дистанция, цена, доступность, без ML.
- Один платёжный провайдер, один рынок, локализация ru/kk, валюта ₸.

## 07 / Что не входит в MVP

`chat` · loyalty/промокоды · AI-рекомендации · автовыплаты провайдерам ·
мультигород · Kafka · Kubernetes · аналитика в Admin · подписки/биллинг ·
второй vertical

Каждый пункт — не «плохая идея», а «идея, для которой сейчас нет данных,
чтобы спроектировать её правильно».

## 08 / Backend-архитектура

Spring Boot, modular monolith, один деплой-юнит, границы модулей — как у
будущих микросервисов, только без сетевых вызовов между ними.

- Gradle multi-module: `auth`, `users`, `providers`, `services`, `booking`,
  `payments`, `reviews`, `notifications`, `search` — каждый: controller →
  service → repository, общение между модулями через Java-интерфейсы
  application-слоя, не HTTP.
- Асинхронность внутри монолита — `ApplicationEventPublisher` +
  `@TransactionalEventListener` (например, `BookingConfirmed →
  Notification`). Дешёвая развязка модулей без Kafka.
- REST API, версионирование `/api/v1`. На MVP — общий API с фильтрацией по
  роли, а не отдельный BFF на клиент; разделять на BFF, когда User App и
  Admin API реально разойдутся.

## 09 / База данных

Один PostgreSQL, одна схема с префиксами таблиц по bounded context — не
schema-per-module и не schema-per-tenant.

> **Важное уточнение терминов**
> «Много бизнесов в одном приложении» — это **не** classic multi-tenant
> SaaS. Не нужна изоляция БД на бизнес. Достаточно `business_id` как
> внешнего ключа на providers/services/bookings — на порядок дешевле в
> реализации и эксплуатации. *(См. `docs/adr/0003-no-full-multitenant-db-isolation.md`
> для полного решения и условий пересмотра.)*

**Расширяемость под vertical в БД:** колонка `vertical_code` + JSONB
`attributes` на generic-таблицах для простых отраслевых полей; отдельные
vertical-таблицы (например, `beauty_master_specialties`) — когда данные
реляционные и часто фильтруются/джойнятся. *(По факту: `Provider.vertical`
— просто строка, без JSONB `attributes`; всё vertical-specific — в
отдельных таблицах, `beauty_master`/`auto_mechanic` и т.д.)*

Redis — кэш, сессии, rate-limit. S3-совместимое хранилище (MinIO локально)
— медиа.

## 10 / Flutter-архитектура

Melos-workspace, пакеты — прагматичный data/domain/presentation, без
ритуала ради ритуала.

- Riverpod и go_router — стек подтверждён.
- `zairo/lib/core/network/dio_client.dart` и
  `core/storage/secure_storage_service.dart` — реальная заготовка под
  `core_network` и `core_storage`; в Phase 1 их логичнее эволюционировать
  в пакеты, а не переписывать с нуля.
- `apps/user_app` и `apps/business_admin` — тонкая сборка поверх пакетов,
  свои деревья роутов, общие route guard'ы из `auth`/`permissions`.

## 11 / Business Admin

Тот же Flutter, тот же язык и дизайн-система, отдельное приложение — не
веб-переписывание с нуля.

Владелец салона часто работает с планшета или стойки администратора —
интерфейс должен быть tablet-first, но не desktop-only. Flutter Web
остаётся опцией позже, без смены стека.

**MVP:** профиль бизнеса, услуги, расписание, список записей, клиенты
(только просмотр). **Не сейчас:** аналитика, управление отзывами, промо.

## 12 / Безопасность

- **AuthN:** собственный JWT access/refresh в модуле `auth`.
  Keycloak/Spring Authorization Server — избыточно для MVP, пересмотреть
  при появлении SSO/enterprise-требований.
- **AuthZ:** RBAC в `permissions` — роли `customer`, `provider_staff`,
  `business_owner`, `platform_admin`.
- **Клиент:** токены только в `flutter_secure_storage`, никогда в обычном
  `SharedPreferences`.
- **Платежи:** клиент никогда не решает, прошёл ли платёж. Источник
  истины — webhook от платёжного провайдера, обработка идемпотентна,
  состояние booking — явная state machine.

## 13 / Deployment

**Локально:** Docker Compose — Postgres, Redis, MinIO, backend одной
командой.

**Staging/Prod MVP:** один управляемый контейнер/VM за балансировщиком,
managed Postgres. Kubernetes — только когда появится реальная причина:
нужна HA с несколькими репликами backend, либо команда и топология
сервисов реально выросли за пределы монолита.

**CI/CD:** GitHub Actions — lint/test/build на PR, автодеплой на staging
при мерже в main, ручной промоут в prod.

## 14 / Roadmap

*(На момент написания — до начала кода. См. предупреждение вверху документа.)*

| Фаза | Содержание | Заметка |
|---|---|---|
| 0 | Product discovery | конкуренты, интервью, MVP-scope, бизнес-модель — до кода |
| 1 | Factory foundation | repo, core_network/ui/auth/profile — строить *вместе* с реальными экранами Beauty, не в вакууме |
| 2 | Marketplace core | providers, services, search, maps, availability, booking, reviews, favorites |
| 3 | Commerce | payments, депозиты, refunds |
| 4 | Beauty vertical | salons, masters, portfolio, booking rules |
| 5 | Business Admin | кабинет бизнеса, минимальный набор |
| 6 | Real pilot | первые реальные бизнесы, один город |
| 7 | Production | деплой, мониторинг, бэкапы, безопасность |
| 8 | Growth | аналитика, промо, лояльность, чат |
| 9 | Second vertical | Auto — проверка KPI: во сколько раз быстрее Beauty |

## 15 / Как добавить Auto без изменения Core

Auto (workshops, mechanics, vehicles, repair services) ложится на те же
примитивы Layer 1, что и Beauty.

- `Provider` → workshop/mechanic, `Service` → repair service, `Booking` →
  запись на ремонт — без новых generic-таблиц.
- Новый `PricingStrategy`: labor + parts вместо фиксированной цены Beauty
  — реализация интерфейса, не правка Core.
- Vehicle-атрибуты (марка, VIN, пробег) — через `vertical_code = auto` +
  JSONB `attributes`, либо отдельная таблица `auto_vehicles`, если данные
  нужно джойнить и фильтровать часто.
- Diagnostics/spare parts — новые vertical-модули по образцу `portfolio` в
  Beauty, не трогая Layer 1.

> **Реализовано** (2026-08-25) — см. `SESSION_NOTES.md`, раздел
> "Реализация vertical-auto". Итоговая форма: `backend/vertical-auto/`
> (`Mechanic`, `Vehicle`, `AutoBooking`, делегирование в Core
> `BookingService`), плюс UI в обоих Flutter-приложениях. `Vehicle` —
> отдельная таблица (не JSONB `attributes`), поскольку данные реляционные
> и владеются пользователем, а не провайдером. Второе правило бронирования
> (машина должна принадлежать заказчику) добавлено сверх того, что здесь
> предполагалось — подтверждает, что паттерн Core/Vertical обобщается не
> только копированием.

## 16 / Как добавить Dental без изменения Core

Dental (dentists, clinics, appointment types) — самый близкий к Beauty
case: Provider = стоматолог/клиника, Service = тип приёма, Booking =
запись на приём почти без нового generic-кода. Это делает Dental хорошим
«вторым тестом» KPI отдельно от Auto — если оба vertical'а собираются
быстро, граница Core/Vertical выбрана верно не случайно.

*(Не реализовано на 2026-08-25 — Auto стал фактическим вторым vertical'ом
вместо Dental.)*

## 17 / Монетизация

Не фиксируется окончательно — но для старта нужна модель без входного
барьера для бизнеса, пока нет доказанного спроса.

**Рекомендация на старт:** комиссия с booking. Она включается только когда
бизнес реально получает клиентов через платформу — совпадает стимулы
платформы и бизнеса, не отпугивает первых партнёров подпиской «в
неизвестность».

Депозит/no-show fee — сначала как механизм доверия для клиента, а не как
строка дохода. Подписка, платное продвижение — рассматривать после того,
как на стороне предложения (бизнесов) появится реальный избыток спроса,
который есть смысл продавать.

## 18 / MVP → Production

- Пилот в одном городе с реальным платёжным провайдером (не sandbox).
- Базовый мониторинг и алерты (логи + Sentry-подобный трекер ошибок).
- Регулярные бэкапы БД и проверенный план восстановления.
- Юридическая проверка: обработка платежей, персональные данные (по
  законодательству РК).
- Канал поддержки пользователей и бизнесов, план отката релиза.

## 19 / Чего не делать сейчас

- **Микросервисы раньше времени** — операционная нагрузка сейчас больше,
  чем выгода от изоляции.
- **Kafka раньше времени** — in-process события на монолите полностью
  закрывают потребность MVP.
- **«Идеальный» абстрактный Core с одним vertical** — Rule of Three: без
  второго примера границы — догадка.
- **Полная multi-tenant изоляция БД** — путает «много бизнесов» с
  «enterprise SaaS», стоит на порядок дороже без нужды.
- **Kubernetes для локальной разработки или раннего prod** — Docker
  Compose и один VM закрывают MVP.
- **Собственный платёжный рельс вместо интеграции с провайдером** —
  комплаенс и риск того не стоят.
- **Chat и recommendation AI до того, как проверен базовый booking-флоу**
  — усложняют продукт, который ещё не доказал спрос.
- **Полный паритет User App и Business Admin с первого дня** — сначала
  доказывается спрос (User App), затем предложение.

## 20 / Первые конкретные задачи

### Phase 0 — Discovery

- Исследование конкурентов на рынке РК (booking-платформы,
  Instagram/WhatsApp-паттерн) — отдельная задача, требует реального
  поиска, не догадок.
- 8–10 интервью с клиентами beauty-услуг + отдельно с владельцами
  салонов/мастерами.
- Исследование доступных платёжных провайдеров для РК-рынка.
- Выбор первого целевого города.

### Phase 1 — подготовка

- Решить: `zairo` становится корнем `app-factory`, или новый репозиторий
  отдельно.
- Каркас Melos-workspace + Gradle multi-module — пустые модули, без
  бизнес-логики.
- ERD доменной модели Provider / Service / Booking / Availability как
  первый архитектурный артефакт.
- Шаблон ADR (architecture decision record) в `docs/adr` для фиксации
  решений вроде тех, что в §19.

> **Решения, нужные до Phase 1** (на момент написания)
> 1. Судьба репозитория `zairo` (§2).
> 2. Целевой город пилота.
> 3. Есть ли уже кандидат платёжного провайдера, или это тоже часть
>    discovery.

---

*Factory Blueprint · черновик v0.1 · снапшот 2026-08-25 из
[опубликованного артефакта](https://claude.ai/code/artifact/59a49cef-f047-488c-a251-551087c40a58)
(2026-08-18/19, Phase 0). Для актуального статуса roadmap — см.
`SESSION_NOTES.md`.*
