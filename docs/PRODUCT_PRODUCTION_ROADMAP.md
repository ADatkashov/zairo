# Factory Production Roadmap

**Дата:** 2026-08-28
**Метод:** код-уровневый аудит (не только документация) backend/, apps/user_app/, apps/business_admin/, packages/, миграций, CI/CD. Каждый пункт ниже подтверждён чтением реального кода (класс/метод/файл:строка) — не восстановлен по названию модуля и не выдуман.
**Роль документа:** ANALYZE → DESIGN → PRIORITIZE → PLAN. Код не менялся, файлы не создавались, кроме этого документа.

---

## 1. Executive Summary

Factory — функционально полный marketplace: два реальных vertical (beauty, auto), обе Flutter-аппки на единой дизайн-системе, backend — modular monolith на Spring Boot с 20+ bounded-context модулями, полное покрытие тестами (Testcontainers), локализация en/ru/kk, работающий CI/CD. Основной цикл — найти услугу → записаться → оплатить → оставить отзыв — реализован и работает в обеих вертикалях без единого TODO-заглушки в бизнес-логике брони.

**Но провести через платформу настоящие деньги сегодня нельзя.** Единственная реализация `PaymentProvider` — `MockPaymentProvider`, который синхронно и безусловно возвращает успех, без единого сетевого вызова. Это касается и оплаты брони, и подписки бизнеса (FREE/PRO) — они идут через один и тот же интерфейс, просто через разные сущности (`Payment` и `SubscriptionCharge`). Карты тоже мок, но здесь новость лучше, чем казалось на первый взгляд: реальный расчёт расстояния (Haversine) в `search`-модуле уже настоящий и не завязан на провайдера карт — мок именно в рендеринге карты на клиенте, не в логике поиска.

Второй по значимости разрыв — **операционная слепота**: `platform-admin` сегодня умеет только логиниться и создавать других админов. Нет ни одного эндпоинта для списка бизнесов, пользователей, дохода, состояния системы. Модерация бизнеса вообще живёт в отдельной, не связанной с `platform-admin` системе авторизации.

Третий — **нет пути в продакшн физически**: ни одного Dockerfile, ни одного deploy-target, все секреты захардкожены в `application.yml`, Android APK подписан debug-ключом с буквальным `TODO` в коде.

Всё остальное — качественная надстройка над прочным основанием, не latanie дыр в фундаменте. Раздел 13 (Phase 0) — это список из 10 пунктов, который закрывает именно три разрыва выше и делает возможным первый реальный пилот с реальными деньгами.

---

## 2. Current Platform State

### Backend (Spring Boot 4.1, Gradle multi-module, `platform-api` — runnable)

| Область | Статус | Основание |
|---|---|---|
| Auth (JWT + refresh tokens) | ✅ Production-ready | HS256, hash-only refresh-token хранение, single-use rotation, revoke-all на смену пароля |
| Users/Providers/Services/Booking | ✅ Production-ready | Полный CRUD, optimistic locking против double-booking, DB unique index как backstop |
| Payments | ⚠️ Каркас реален, провайдер — mock | Идемпотентность, refund-эндпоинт, событийная связка с booking — всё настоящее; единственный провайдер синхронный и безусловно успешный |
| Reviews / Favorites | ✅ Production-ready | — |
| Search / ranking | ✅ Production-ready (для текущего масштаба) | Детерминированный ranking, реальный Haversine, без ML — осознанно |
| Beauty vertical | ✅ Production-ready | masters, portfolio, booking rules |
| Auto vertical | ✅ Production-ready | mechanics, vehicles, booking rules — функциональный паритет с beauty подтверждён |
| Storage (MinIO) | ⚠️ Работает, без валидации типа файла | Ключ — UUID (не угадать), размер ограничен framework'ом, content-type не проверяется |
| Subscriptions (FREE/PRO) | ✅ Логика реальна, ⚠️ провайдер — mock | Лимиты, `@Scheduled` renewal, grace period, downgrade — всё настоящее; charge идёт через тот же mock |
| Notifications | ⚠️ Email-only, dev-stub | Логирует письмо в консоль, реально не отправляет; push/SMS не спроектированы вообще |
| Platform Admin | ⚠️ Скелет | 4 эндпоинта: login/me/create-admin/audit-log. Нет ни одного операционного/аналитического |
| Catalog (Category→BusinessType→Service) | ✅ Production-ready | Построено в этой сессии |
| provider-insights (customer history, dashboard) | ✅ Production-ready | Live-композиция, без хранимых агрегатов — та же логика нужна для platform-level метрик |
| Country / multi-region основа | ⚠️ Фазы A/B/C/F есть, D/E — нет | JSONB-переводы контента и delivery/SMS-адаптеры сознательно отложены |

### Flutter (`apps/user_app`, `apps/business_admin`, 4 пакета `packages/core_*`)

Design System (`core_ui`) полностью применён в обеих аппках, локализация en/ru/kk с полным паритетом (kk — на ревью носителя, не баги). CI (`flutter analyze` + `flutter test`) зелёный по всем 6 пакетам.

- **Maps**: `LocationService` — реальная абстракция (уже есть точка подмены), `MockLocationService` — единственная реализация, возвращает захардкоженную точку в Алматы. `MockMapScreen` — статичный placeholder без SDK карты вообще.
- **Mobile release**: Android release build подписан debug-ключом (буквальный `TODO` в коде обеих аппок), нет flavor/environment-конфигурации (один хардкод `10.0.2.2`/`localhost` на аппку), нет crash reporting, нет push-клиента, нет ничего для Google Play (ни `fastlane/`, ни `google-services.json`).

### Infrastructure

CI/CD — реальный, построен в этой сессии (`.github/workflows/`), проверен на живых прогонах. Всё остальное — нет: ни одного Dockerfile, ни одного deploy-target, ноль `${ENV_VAR}` в конфигурации (все секреты — литералы в `application.yml`), ни бэкапов, ни мониторинга сверх `/actuator/health`.

---

## 3. Pilot Definition

### Pilot MVP — обязательно для первого реального бизнеса

| Возможность | Почему обязательна | Есть | Отсутствует | Acceptance criteria |
|---|---|---|---|---|
| Реальный платёжный шлюз (booking) | Без этого клиент физически не платит бизнесу | `PaymentProvider`-порт, `Payment`-сущность, идемпотентность, refund-эндпоинт | Реальная реализация интерфейса, webhook | Клиент проходит реальную оплату картой/Kaspi, деньги видны в дашборде провайдера |
| Реальный платёжный шлюз (подписка) | Иначе Factory не зарабатывает на самих бизнесах | То же (через `SubscriptionCharge`) | Та же реализация переиспользуется | Business owner проходит апгрейд на PRO с реальным списанием |
| Webhook + идемпотентная обработка | Реальные шлюзы асинхронны, синхронного `charge()` недостаточно | Ничего (0 эндпоинтов) | Полностью новый функционал | Повторная доставка webhook не создаёт дубликат/двойное списание |
| Booking↔Payment консистентность | Сейчас бронь может остаться CONFIRMED без оплаты навсегда | `@Transactional` внутри booking | `PENDING_PAYMENT`-статус + sweep-job | Заброшенная неоплаченная бронь автоматически отменяется |
| Причина отмены + no-show | Нужно бизнесу для понимания потерь, клиенту — для понятной политики | `BookingStatus` enum | Новое поле/статус | Отмена требует причины; неявка помечается вручную владельцем |
| Реальная карта на клиенте | Иначе «рядом со мной» — не факт | `LocationService`-абстракция, реальный Haversine на backend | `MapRenderer` + SDK-провайдер | Пользователь видит реальную карту и реальное расстояние |
| Внешние секреты + реальный CORS | Иначе задеплоить некуда безопасно | Всё захардкожено локально | `${ENV_VAR}` + прод-origin в CORS | Ни один секрет не в git; фронтенд с реального домена проходит CORS |
| Docker-образ + одно окружение | Физически некуда деплоить | `bootBuildImage` доступен из коробки (Spring Boot Gradle plugin) | Сборка образа + один hosting-target | `docker run` образа поднимает platform-api с внешней БД |
| Android release-подпись | Иначе нельзя выдать APK бизнесу для реального использования | Debug-подпись работает как временная | Реальный keystore + секреты подписи | `flutter build apk --release` подписан не debug-ключом |
| Rate limiting на auth | Первая реальная публичная точка входа — первая цель брутфорса | Ничего | Простой лимитер (bucket4j/in-memory) | N неудачных попыток логина в минуту → блокировка |
| Минимальный operations-обзор | Владелец платформы должен видеть, что происходит | `provider-insights`-паттерн как образец | Список бизнесов/юзеров/броней/платежей в `platform-admin` | Админ видит список бизнесов и их статус подписки без прямого SQL |

### Can Wait — осознанно не для первого пилота

- **Advanced analytics / conversion funnel** — событийная модель (раздел 10) закладывается, но полноценный funnel-дашборд подождёт реального трафика.
- **Сложные loyalty-механики** — промокод/скидка на первый визит логичны, программа лояльности с баллами — нет.
- **Дополнительные вертикали** — beauty+auto достаточно для пилота.
- **Сложные промокоды** (проценты, стек правил, категории) — простой флэт-промокод достаточен, если вообще понадобится в Phase 0.
- **Расширенный chat** — файловые вложения, групповые треды, read receipts. Базовый 1:1 текстовый чат — пограничный случай, см. Phase 1.
- **Advanced recommendations / ML-ranking** — детерминированный ranking справляется на масштабе пилота.
- **Push-уведомления** — email-канал (пусть и требует реальных SMTP-креды) достаточен для пилота меньше N пользователей; push — Phase 2.
- **Мультивалютность / вторая страна** — Phase D/E архитектуры country уже осознанно отложены, триггер не наступил.
- **Reconciliation job** (Payment vs provider) — оправдан только при объёме, где ручная сверка становится больной; для пилота — нет.

---

## 4. Production Readiness Matrix

Легенда Priority: **P0** — блокирует пилот с реальными деньгами · **P1** — нужно для доверия/удобства пилота · **P2** — рост после пилота · **P3** — масштаб. Effort: **S/M/L/XL** — относительный размер, не календарная оценка (см. раздел 18 — почему я не даю фейковых дней).

**Снимок на 2026-08-28.** С этой даты выполнено (детали и даты — в соответствующих нарративных разделах, здесь таблица намеренно не переписана построчно, чтобы не расходиться с ними): cancellation reason + no-show (раздел 7), refund-failure видимость (разделы 5/12), Docker-образ + внешние секреты + настраиваемый CORS (раздел 11), payment provider + pilot country решены (раздел 19).

### Payments

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| booking payment | Mock, синхронный | Реальный шлюз | P0 | Payment Provider Decision | L | Реальное списание за бронь |
| subscription payment | Mock, тот же порт | Реальный шлюз | P0 | то же | S (переиспользует booking-интеграцию) | Реальное списание за PRO |
| payment provider abstraction | `PaymentProvider` интерфейс, 1 реализация | Вторая (реальная) реализация | P0 | Provider Decision | M | DI-подмена без изменения вызывающего кода |
| payment status | `PENDING/SUCCEEDED/FAILED/REFUNDED` — есть | Добавить промежуточные async-статусы если провайдер их даёт | P1 | webhook | S | Статус отражает реальное состояние у провайдера |
| webhook | Отсутствует полностью | Новый контроллер + подпись + идемпотентность | P0 | Provider Decision | L | Повтор webhook не дублирует эффект |
| idempotency | Есть на уровне Payment/SubscriptionCharge (reuse строки) | Добавить dedup по provider event id для webhook | P0 | webhook | M | Двойная доставка = один эффект |
| failed payment | Ловится, помечается FAILED | Уведомление клиенту при провале (сейчас есть только для подписки) | P1 | notifications | S | Клиент узнаёт о неудачной оплате брони |
| refund | Реальный эндпоинт, автотриггер на отмену | Failure-path сейчас только логируется | P0 | admin-видимость | M | Неудачный refund виден админу, не теряется молча |
| cancellation | Событийная, decoupled от payment (ADR-0002) | — (архитектурно решено) | — | — | — | — |
| reconciliation | Отсутствует | Job сверки Payment vs provider | P3 | реальный провайдер, объём | L | Can Wait — см. раздел 3 |

### Booking

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| availability | Optimistic lock (`@Version`) + DB unique index | — (production-ready) | — | — | — | — |
| cancellation | Работает, decoupled рефанд | — | — | — | — | — |
| cancellation reason | Отсутствует | Новое поле на Booking | P0 | — | S | Отмена требует причины |
| no-show | Отсутствует (ни поля, ни статуса) | Новый статус/флаг + эндпоинт для владельца | P0 | — | M | Владелец может пометить неявку |
| booking lifecycle | 4 статуса, чёткие переходы | Добавить `PENDING_PAYMENT` | P0 | payment architecture (раздел 5) | M | Бронь не «зависает» CONFIRMED без оплаты |
| race conditions | Решено (optimistic lock + unique index) | — | — | — | — | — |
| duplicate booking | Решено тем же механизмом | — | — | — | — | — |
| payment ↔ booking consistency | Две раздельные транзакции, ничего не откатывает бронь | Sweep-job для заброшенных PENDING_PAYMENT | P0 | то же | M | Неоплаченная бронь автоотменяется через N минут |

### Maps / Geo

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| provider abstraction | Backend: нет (не нужна — см. ниже). Client: `LocationService` есть | `MapRenderer`-абстракция на клиенте | P0 | Provider Decision | M | Подмена SDK без переписывания экрана |
| current mock implementation | `MockMapScreen` — статичный placeholder | Заменить на реальный SDK-рендер | P0 | то же | M | Пользователь видит настоящую карту |
| geolocation | `LocationService`/`MockLocationService` — абстракция есть | Реальная реализация (device GPS) | P0 | geolocator-плагин | S | Реальные координаты устройства |
| coordinates | `Provider.latitude/longitude` — ручной ввод | Геокодирование опционально | P2 | — | M | Can Wait для пилота (ручной ввод приемлем) |
| distance calculation | **Реальный Haversine**, не мок | — (production-ready) | — | — | — | — |
| nearby search | Работает на реальном расстоянии | — | — | — | — | — |
| API key/security | Нет ключей нигде | Управление ключом (env var, не в git) | P0 | Provider Decision | S | Ключ не в репозитории |
| provider cost | Не оценивалась | Оценка перед выбором | P0 (decision) | — | — | См. раздел 19 |

### Notifications

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| push registration | Отсутствует полностью | Device-token эндпоинт | P2 | FCM выбор | M | Can Wait для пилота |
| device token | Отсутствует | То же | P2 | — | — | — |
| confirmation | Есть (email, но лог, не отправка) | Реальный SMTP/провайдер | P0 | — | S | Клиент реально получает письмо |
| reminder | Отсутствует (нет события «за час до брони») | Новый scheduled job | P1 | — | M | Клиент получает напоминание |
| cancellation | Есть (email, лог) | Реальная отправка | P0 | то же, что confirmation | S | — |
| payment notification | Есть только для подписки (fail/past-due) | Добавить для booking payment (success + fail) | P1 | — | S | Клиент узнаёт об успехе/провале оплаты |
| delivery/error handling | Отсутствует (exception теряется) | Try/catch + минимальный retry или dead-letter лог | P1 | — | M | Провал отправки не теряется бесследно |

### Subscription

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| FREE | Лимиты enforced (1 бизнес/3 сотрудника/30 броней) | — | — | — | — | — |
| PRO | Лимиты enforced (5/20/unlimited, $29) | — | — | — | — | — |
| limits | 4 проверки, все реальные | — | — | — | — | — |
| usage | Проверяется при создании | Эндпоинт для клиента «сколько уже использовано» | P1 | — | S | Business admin видит текущее использование лимитов |
| upgrade | Реальный charge через mock-провайдер | Реальный провайдер | P0 | Provider Decision | S (переиспользует booking-интеграцию) | — |
| downgrade | Работает, ресурсы не блокируются ретроактивно | — (осознанное поведение) | — | — | — | — |
| cancellation | `cancelAtPeriodEnd` — реален | — | — | — | — | — |
| renewal | Два `@Scheduled` job, реальная логика | — (production-ready после реального провайдера) | — | — | — | — |
| failed payment | PAST_DUE + 7-дневный grace — реален | — | — | — | — | — |
| prorated changes | Отсутствует | Не нужно для пилота | P3 | — | — | Can Wait |
| admin plan assignment | Отсутствует | Новый эндпоинт в platform-admin | P1 | — | S | Админ вручную меняет план бизнесу (поддержка/пилот-льготы) |

### Admin / Operations

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| platform dashboard | Отсутствует (0 операционных эндпоинтов) | Новый read-composition модуль (по образцу provider-insights) | P0 | — | L | См. раздел 9 |
| users | Нет списка | Live-query эндпоинт | P0 | — | S | — |
| businesses | Нет списка (модерация — отдельная система) | Live-query эндпоинт | P0 | — | S | — |
| subscriptions | Нет обзора | Live-query эндпоинт | P0 | — | S | — |
| bookings | Нет обзора | Live-query эндпоинт | P1 | — | S | — |
| payments | Нет обзора | Live-query эндпоинт + failed-refund view | P0 | — | S | — |
| revenue | Нет вообще | MRR из SubscriptionCharge | P1 | — | S | — |
| system health | Только `/actuator/health` | Нужна новая модель отслеживания ошибок (раздел 9-10) | P2 | analytics-архитектура | M | Can Wait минимально, но failed-refund — нет |
| audit logs | Узкое покрытие (только catalog+platform-admin-created) | Добавить в provider-moderation | P1 | — | S | Модерация бизнеса аудируется |

### Infrastructure

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| Docker | Отсутствует, но `bootBuildImage` доступен бесплатно | Собрать образ, проверить | P0 | — | S | `docker run` поднимает platform-api |
| staging | Отсутствует | Один hosting-target | P0 | Docker | M | Реальный URL, доступный команде |
| production | Отсутствует | Второй target после staging | P1 | staging обкатан | M | — |
| CI/CD | ✅ Реален, проверен на живых прогонах | — | — | — | — | — |
| secrets | 100% захардкожено, 0 `${ENV_VAR}` | Внешние переменные для всех credential | P0 | — | S | Ни один секрет не в git |
| database | Postgres, миграции чистые | Managed instance для staging/prod | P0 | staging | S | — |
| migrations | Flyway, V1–V26, чисто | — | — | — | — | — |
| backups | Отсутствуют | pg_dump расписание или managed backup | P0 | production | S | Восстановление проверено хотя бы раз |
| logging | Только консоль Spring Boot | Не блокирует пилот | P2 | — | — | Can Wait минимально |
| monitoring | Только `/actuator/health,info` | Базовый uptime-мониторинг | P1 | production | S | Алерт при падении health-check |
| alerts | Отсутствуют | Минимум — на падение сервиса | P1 | monitoring | S | — |

### Mobile

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| release build | Собирается | — | — | — | — | — |
| signing | Debug-ключ, буквальный `TODO` в коде | Реальный keystore | P0 | — | S | `flutter build apk --release` не debug-подписан |
| environment configuration | Один хардкод на аппку | dev/staging/prod через `--dart-define` | P0 | staging существует | S | Аппка указывает на реальный backend |
| API configuration | Хардкод `10.0.2.2`/`localhost` | То же, что выше | P0 | — | — | — |
| crash reporting | Отсутствует | Sentry/Crashlytics | P1 | — | S | Ошибки production видны команде |
| push notifications | Отсутствует (ни backend, ни client) | FCM | P2 | — | L | Can Wait для пилота |
| Google Play readiness | Ничего (нет fastlane/assets/google-services.json) | Полный store-listing pass | P1 | signing | M | — |

### Security

См. полную таблицу рисков в разделе 12 — здесь сведено для матрицы.

| Area | Current State | Production Gap | Priority | Dependencies | Effort | Acceptance Criteria |
|---|---|---|---|---|---|---|
| authentication | JWT HS256, refresh — solid | — | — | — | — | — |
| authorization | `ProviderOwnership`, консистентно проверено | — | — | — | — | — |
| tenant/business isolation | Не найдено пробелов в выборке | Расширить проверку по мере роста | P2 | — | — | — |
| sensitive data | В логах не найдено | — | — | — | — | — |
| secrets | В git, не в env | См. Infrastructure | P0 | — | S | — |
| API security | CORS = localhost-only | Реальный origin перед деплоем | P0 | staging/prod домен | S | — |
| rate limiting | Отсутствует | Простой лимитер на auth | P0 | — | S | — |
| audit | Узкое покрытие | См. Admin/Operations | P1 | — | S | — |
| OWASP risks | SQLi чист, upload без content-type валидации | Ограничить upload по типу | P1 | — | S | — |

---

## 5. Payment Architecture

### Current architecture (код-подтверждено)

```
Client → POST /bookings                         → Booking(status=CONFIRMED)  ← без оплаты вообще
Client → POST /bookings/{id}/payments            → PaymentsService.createPayment
                                                   → PaymentProvider.charge()  [синхронно]
                                                   → MockPaymentProvider: всегда succeeded, без сети
                                                   → Payment(status=SUCCEEDED|FAILED)

Booking и Payment — ДВЕ отдельные транзакции. Ничего не связывает их состояния автоматически.
CONFIRMED-бронь без Payment или с FAILED-Payment может существовать сколь угодно долго.

Отмена:
Booking.cancel() → BookingCancelledEvent (AFTER_COMMIT, REQUIRES_NEW)
                  → находит SUCCEEDED Payment → PaymentsService.refundPayment()
                  → PaymentProvider.refund() → при неудаче: только log.error, без retry

Подписка (параллельный, отдельный путь):
SubscriptionRenewalService.chargeForRenewal() → тот же PaymentProvider
                                               → SubscriptionCharge (ОТДЕЛЬНАЯ сущность от Payment)
```

**Ключевой архитектурный факт**: `PaymentProvider` — это уже чистый порт (2 метода: `charge`, `refund`), и booking-платежи, и subscription-платежи уже проходят через один и тот же интерфейс, просто пишут в разные сущности. Смена мока на реальный провайдер технически — это **одна новая реализация интерфейса**, а не переписывание вызывающего кода. Это хорошая новость: сама абстракция спроектирована правильно с первого раза.

**Что архитектурно отсутствует**: интерфейс полностью синхронный. У реального провайдера charge почти всегда асинхронный (redirect/3-D Secure/QR-подтверждение) — текущая форма `charge() → succeeded/failed сразу` не выдержит реальной интеграции без изменений.

### Target architecture

```
Booking создаётся сразу как PENDING_PAYMENT  (новый статус)
   ↓
POST /bookings/{id}/payments
   → Payment(status=PENDING) создаётся
   → PaymentProvider.charge() возвращает НЕ финальный результат,
     а client confirmation token / redirect URL / QR (форма зависит от провайдера)
   ↓
Клиент завершает оплату на стороне провайдера (3-D Secure / Kaspi-подтверждение / и т.п.)
   ↓
Провайдер вызывает НАШ webhook: POST /webhooks/payments/{provider}
   ↓
Webhook handler (новый, per-provider):
   1. проверяет подпись (HMAC/провайдер-специфично)
   2. ищет Payment по provider payment/session id
   3. идемпотентность: если Payment уже SUCCEEDED/FAILED — no-op (дедуп по event id провайдера)
   4. переводит Payment PENDING → SUCCEEDED | FAILED
   5. SUCCEEDED → та же транзакция переводит Booking PENDING_PAYMENT → CONFIRMED
   6. FAILED → Booking остаётся PENDING_PAYMENT, клиент видит статус, может повторить оплату

Новый sweep-job (по образцу уже существующего SubscriptionRenewalJob):
   PENDING_PAYMENT дольше N минут без успешного webhook → автоотмена брони, слот освобождается
```

**Новые компоненты**:
1. `BookingStatus.PENDING_PAYMENT` (плюс существующие 4).
2. `PaymentWebhookController` + per-provider `PaymentWebhookProcessor` (парсинг + верификация подписи + вызов `PaymentsService`).
3. Таблица/поле для дедупа webhook-событий (или переиспользование `Payment.status` как guard — достаточно, если провайдер гарантирует один финальный статус на payment id; нужен отдельный лог событий, если провайдер может слать несколько разных event-types на один платёж).
4. `PENDING_PAYMENT`-sweep `@Scheduled` job.
5. Refund failure перестаёт быть «залогировано и забыто» — нужно поле `refundAttempts`/`lastRefundError` на Payment, видимое в Platform Admin (раздел 9).

Ничего из этого не требует трогать `Booking`/`AvailabilitySlot`'s double-booking защиту (optimistic lock + unique index) — она уже надёжна и не связана с payment flow.

---

## 6. Maps Architecture

### Что уже реально (важная поправка к общему впечатлению «карты — мок»)

`DistanceCalculator` в `search`-модуле — настоящая формула Haversine, не заглушка. Ranking по расстоянию в поиске **уже корректен и не зависит от провайдера карт**. Мок — исключительно в (а) рендеринге карты на клиенте и (б) отсутствии реального GPS на клиенте. Backend вообще не нуждается в `MapProvider`-абстракции для того, что он уже делает — это чисто client-side задача.

### Target abstraction

```
Client (Flutter):

LocationService                      MapRenderer (новая абстракция —
 ├── MockLocationService (есть)       сейчас MockMapScreen — просто
 └── DeviceLocationService (новая,    захардкоженный виджет без абстракции)
     оборачивает geolocator-плагин)   ├── MockMapRenderer (текущий контент)
                                      ├── GoogleMapsRenderer (google_maps_flutter)
                                      ├── MapboxRenderer (mapbox_gl)
                                      └── OsmRenderer (flutter_map + OSM tiles)

Backend: изменений не требуется. Геокодирование (адрес → координаты) — отдельная,
осознанно откладываемая фича (Phase 2) — ручной ввод lat/lng бизнесом приемлем для
пилота с горсткой businesses, онбордящихся вручную.
```

### Рекомендация для казахстанского пилота

Три реальных варианта, с оговоркой — актуальные условия/цены нужно проверить на момент интеграции, ниже — архитектурная, не коммерческая оценка:

- **Google Maps** — самый знакомый пользователю UX, но платный с ростом нагрузки и требует привязки биллинга с первого дня.
- **Mapbox** — щедрый free tier, дешевле при росте, чуть больше настройки.
- **OSM (через `flutter_map` + бесплатный/self-hosted тайл-сервер)** — нулевая стоимость лицензии, контролируемая стоимость инфраструктуры, но меньше «из коробки» полировки.
- **2ГИС** — стоит рассмотреть отдельно: в Казахстане/СНГ у него исторически сильное покрытие бизнес-данных (что релевантно маркетплейсу услуг), но нужно отдельно проверять текущие условия API.

Для пилота с малым числом реальных бизнесов я бы рекомендовал **OSM/Mapbox** как старт (контролируемая стоимость, абстракция уже закладывается — сменить на Google Maps позже — это одна новая реализация `MapRenderer`, не переделка экрана). Финальный выбор — раздел 19 (бюджет инфраструктуры).

---

## 7. Booking Reliability

**Уже надёжно (код-подтверждено, не требует работы)**:
- Double-booking невозможен — двойная защита: optimistic lock (`@Version` на `AvailabilitySlot`) ловит гонку в приложении, `UNIQUE INDEX` на `availability_slot_id` в таблице `booking` — backstop на уровне БД, даже если бы приложенческая защита была обойдена.
- Отмена брони архитектурно decoupled от возврата денег через `ApplicationEventPublisher` (ADR-0002) — надёжный, проверенный паттерн, уже используется для notifications тем же способом.

**Сделано (2026-08-28)**:
- ✅ **Cancellation reason** — `Booking.cancellationReason` (V27), опциональное поле в `POST /bookings/{id}/cancel`. Не обязательное на уровне API (см. `CancelBookingRequest`'s doc comment — все существующие клиенты вызывают cancel без тела вообще; сделать его обязательным — отдельное продуктовое решение, не техническое).
- ✅ **No-show** — новый `BookingStatus.NO_SHOW`, `POST /bookings/{id}/no-show`, owner-only (через `ProviderOwnership`, тот же паттерн, что и остальные provider-scoped мутации).
- ✅ **Refund-failure видимость** (из раздела 5/12) — `Payment.refundFailureReason` (V28), сохраняется на строке до того, как `refundPayment` бросит исключение (`noRollbackFor`, иначе транзакция откатила бы именно эту запись). Факт больше не теряется только в логе.

**Требует работы (Phase 0)**:
- **Booking↔Payment консистентность** — см. раздел 5 (`PENDING_PAYMENT` + sweep job). Это самый весомый оставшийся пробел в booking-надёжности: технически бронь может быть «подтверждена» без единого успешного платежа, если между двумя раздельными запросами что-то пошло не так, и ничего в системе этого не заметит. Сознательно не делалось в этом заходе вместе с cancellation reason/no-show — требует всей webhook-цепочки (0.2–0.4) целиком, не по частям (см. исправленную заметку в разделе 20).

---

## 8. Subscription Readiness

**Уже реально работает (код-подтверждено)**: enforcement лимитов — 4 отдельные проверки (businesses/staff/bookings-per-month/recurring-schedule allowed), точные значения FREE (1 business / 3 сотрудника / 30 броней в месяц) и PRO (5 businesses / 20 сотрудников / unlimited броней, $29/мес); два `@Scheduled` job — ежедневный renewal и отдельный downgrade просроченных grace-периодов; grace period 7 дней после неудачного списания перед принудительным даунгрейдом; поведение downgrade осознанно не блокирует уже существующие ресурсы ретроактивно (только новое создание упирается в лимит FREE) — это дизайн-решение, а не недосмотр.

**Единственный реальный пробел — тот же, что у booking-платежей**: списание идёт через `MockPaymentProvider`. Хорошая новость архитектурно: это самая дешёвая часть Phase 0 (раздел 13, п. 0.7) — `SubscriptionRenewalService`/`SubscriptionService` уже вызывают тот же `PaymentProvider`-bean, что и booking-платежи, просто пишут в отдельную сущность `SubscriptionCharge` (не `Payment`). Новая реализация провайдера из п. 0.2 подключается сюда без дополнительной интеграционной работы — буквально смена одного DI-бина.

**Второстепенные пробелы**, не блокирующие пилот технически, но стоящие явного решения:
- **Usage endpoint** — сегодня business owner узнаёт о лимите только через 402 при попытке его превысить, посмотреть «сколько уже использовано» заранее негде. Дёшево (Phase 1).
- **Admin manual plan assignment** — в `PlatformAdminController` нет ни одного эндпоинта, меняющего план бизнеса. Реальные переговоры с первым пилотным бизнесом почти наверняка потребуют ручной льготы («первый месяц PRO бесплатно») — стоит рассмотреть на границе Phase 0/1, не откладывать бездумно в Can Wait.
- **Prorated changes** — подтверждено отсутствуют (`Subscription.markUpgradedToPro`'s собственный doc-comment: «no proration for the switch from FREE»). Осознанно Can Wait при малом числе пилотных бизнесов.

Важный нюанс для реализации: subscription-платежи и booking-платежи — параллельные, не унифицированные механизмы (`SubscriptionCharge` — отдельная сущность от `Payment`, хоть оба и идут через один `PaymentProvider`-порт). Это не технический долг, а осознанное разделение по bounded context — но при реализации п. 0.2/0.7 в Phase 0 это значит: один новый класс провайдера, две отдельные точки его вызова, не одна.

---

## 9. Platform Admin / Operations

Явное требование: **не строить дашборд, если backend не может отдать корректные данные**. Ниже — честное разделение по этому принципу.

### Можно построить прямо сейчас (live-query, без новой модели данных)

По образцу `provider-insights` (уже проверенный на практике паттерн: считать на лету из Booking/Payment/Provider/Subscription, без хранимых агрегатов — оправдано на текущем масштабе, тот же вывод, что и для provider-level дашборда):

- **Users**: total (простой COUNT).
- **Businesses**: total, active, pending moderation, blocked (COUNT по `Provider.status`).
- **Subscriptions**: FREE vs PRO count, active, cancelled (COUNT по `Subscription.plan/status`).
- **Bookings**: today/week/month, completed/cancelled (COUNT по `Booking.status` + `createdAt`).
- **Payments**: successful/failed/pending, refunds (COUNT по `Payment.status`).
- **Revenue**: MRR = SUM активных `SubscriptionCharge.amount` за период. **Важная бизнес-оговорка**: модель монетизации — только подписка, платформа не берёт комиссию с брони. Значит GMV (сумма всех Payment по броням) — это метрика здоровья маркетплейса, **не** доход платформы; смешивать их на одном тайле дашборда будет вводить в заблуждение.
- **Top businesses/services/categories**: GROUP BY на Booking — нормально на масштабе пилота, может потребовать индекса/кеша при росте (не сейчас).

### Требует новой модели данных (раздел 10 — analytics_event)

- **New users/businesses за период** (нужны события `USER_REGISTERED`/`BUSINESS_REGISTERED`, а не только текущий COUNT).
- **DAU/WAU/MAU** — сегодня в системе нет вообще ничего, что отслеживает «пользователь был активен в день X» (выдача JWT — слабый прокси, не активность). Нужен хотя бы простейший «последняя активность» timestamp на пользователе, или вывод из analytics_event.
- **Conversion funnel** (search → view → booking) — ровно то, для чего заложены no-op события из раздела 10.

### Нельзя построить честно вообще, пока не появится новое отслеживание

- **System health / failed jobs / failed notifications**: сегодня ничего не трекает это структурированно — провал отправки письма или неудачный refund просто улетает в `log.error` без queryable записи. Нужна новая таблица (`operational_failure` или расширение той же `analytics_event`) **до** того, как на дашборде появится честный тайл «ошибки».

### MVP Platform Dashboard (рекомендация)

Phase 1 (раздел 14): Users/Businesses/Subscriptions/Bookings/Payments/Revenue-MRR — все live-query, без новой модели. Phase 2: funnel + DAU/WAU/MAU (после event-модели). System health — не раньше, чем появится failed-refund/failed-notification трекинг (Phase 0/1 пограничная зона: как минимум failed-refund-view нужен уже в Phase 0 из-за финансового риска).

---

## 10. Analytics

### Важная находка: часть событий уже существует

`SearchPerformedEvent`, `ProviderViewedEvent`, `BookingAttemptedEvent` (search/providers/booking модули), `BookingConfirmedEvent`, `BookingCancelledEvent` (booking модуль) — **уже публикуются** в этой сессии и раньше, сейчас с нулём слушателей (no-op, заложены заранее именно для будущей аналитики). Это значит: для доброй половины запрошенного списка событий publish-сторона уже готова, нужен только новый слушатель.

### Данные события → что уже есть vs что нужно добавить

| Событие | Publish-точка | Статус |
|---|---|---|
| `SEARCH_PERFORMED` | `SearchPerformedEvent` | ✅ Уже публикуется |
| `BUSINESS_VIEWED` | `ProviderViewedEvent` | ✅ Уже публикуется |
| `BOOKING_CREATED` (как попытка) | `BookingAttemptedEvent` | ✅ Уже публикуется (и на успех, и на провал) |
| `BOOKING_COMPLETED`/аналог confirm | `BookingConfirmedEvent` | ✅ Уже публикуется |
| `BOOKING_CANCELLED` | `BookingCancelledEvent` | ✅ Уже публикуется |
| `USER_REGISTERED` | — | ❌ Новая publish-точка (auth/users) |
| `BUSINESS_REGISTERED` | — | ❌ Новая (providers) |
| `BUSINESS_APPROVED` | — | ❌ Новая (ProviderController.updateStatus) |
| `SERVICE_VIEWED` | — | ❌ Новая (нет текущего эквивалента ProviderViewedEvent на уровне услуги) |
| `PAYMENT_STARTED`/`SUCCEEDED`/`FAILED` | — | ❌ Новые (payments) |
| `BOOKING_NO_SHOW` | — | ❌ Заблокировано на добавлении no-show поля (раздел 7) |
| `REVIEW_CREATED` | — | ❌ Новая (reviews) |
| `SUBSCRIPTION_STARTED`/`CANCELLED` | — | ❌ Новые (subscriptions) |

### Где хранить

Один новый append-only `analytics_event` (event_type, occurred_at, actor_user_id nullable, provider_id nullable, payload jsonb), не отдельная БД/warehouse и не Kafka — это прямое продолжение уже принятого архитектурного решения (ADR-0002: in-process события, не Kafka). Пишется теми же `@TransactionalEventListener(phase = AFTER_COMMIT)`, что уже используется для notifications — тот же, проверенный на практике паттерн, не новая парадигма.

**Явно не нужно на этом масштабе**: отдельная OLAP-БД, event bus между процессами, потоковая обработка. Один индексируемый по `event_type + occurred_at` table в той же Postgres справится на объёме пилота и следующей пары лет роста без изменений — если объём когда-нибудь оправдает вынос в отдельное хранилище, это самостоятельное решение с отдельным триггером (тот же принцип, что уже применён к multi-tenant isolation в ADR-0004).

---

## 11. Infrastructure

**Уже готово**: CI/CD (`flutter-ci.yml`, `backend-ci.yml`, `build-artifacts.yml`) — реально проверен на живых прогонах GitHub Actions, включая сборку Android APK и backend bootJar. Flyway-миграции чистые, без пропущенных constraint'ов на денежно-критичных таблицах.

**Сделано (2026-08-28)**:
- ✅ **Docker-образ** — `./gradlew :platform-api:bootBuildImage`, без единого Dockerfile (Cloud Native Buildpacks). Реально запущен `docker run` с переменными окружения против существующих Postgres/MinIO-контейнеров из `infrastructure/docker-compose.yml` — Flyway применил миграции, `/actuator/health` ответил `{"status":"UP"}`. Acceptance criteria из раздела 3 подтверждён живым прогоном, не только сборкой.
- ✅ **Внешняя конфигурация секретов** — `DB_URL`/`DB_USERNAME`/`DB_PASSWORD`/`JWT_SECRET`/`PLATFORM_ADMIN_JWT_SECRET`/`MINIO_ENDPOINT`/`MINIO_ACCESS_KEY`/`MINIO_SECRET_KEY`/`MINIO_BUCKET`/`SERVER_PORT`/`CORS_ALLOWED_ORIGINS` — каждый теперь `${ENV_VAR:dev-default}` в `application.yml`. Поведение не изменилось (Spring и раньше разрешал override через env var без этого синтаксиса), но теперь это явно и грепается — раньше был риск тихо не переопределить что-то важное при первом деплое.
- ✅ **CORS готов к реальному origin** — `WebConfig` читает `app.cors.allowed-origins` (env var `CORS_ALLOWED_ORIGINS`, дефолт не изменился — `http://localhost:*`), добавить реальный домен теперь не требует правки Java-кода.

**Required before pilot**:
- Одно staging-окружение (любой managed host — решение по бюджету, раздел 19).
- Managed Postgres на staging/production (не self-hosted в контейнере рядом с приложением).
- Бэкапы БД (хотя бы cron `pg_dump` + off-site хранение, необязательно сразу managed-решение).
- Базовый uptime-мониторинг + алерт на падение `/actuator/health`.

**Can wait**:
- Полноценный APM/Prometheus/Sentry (структурного логирования нет вообще, но для пилота консольных логов + health-check достаточно).
- Production-окружение как отдельный от staging target — можно временно использовать staging как «prod» для первого пилотного бизнеса при малом риске, но лучше не смешивать, если бюджет позволяет.
- Автоматизированный rollback-механизм — на масштабе пилота ручной откат через redeploy предыдущего образа приемлем.

---

## 12. Security

Lightweight production security review — код-проверено, не чек-лист по памяти.

| Risk | Severity | Current State | Recommendation | Must Fix Before Pilot? |
|---|---|---|---|---|
| Нет rate limiting на login/register | High | Полностью отсутствует | Простой in-memory лимитер (или bucket4j) на auth-эндпоинты | **Да** |
| ~~Все секреты в git (JWT, DB, MinIO)~~ | High | ✅ **Сделано 2026-08-28** — все теперь `${ENV_VAR:dev-default}`, значения по умолчанию не изменились (Spring и так разрешал override), но теперь явно и грепается. JWT-секреты по-прежнему публично в истории git — сгенерировать новые перед реальным деплоем, не переиспользовать | — | Готово |
| ~~CORS = localhost-only~~ | Medium | ✅ **Сделано 2026-08-28** — `app.cors.allowed-origins`/`CORS_ALLOWED_ORIGINS`, дефолт не менялся. Добавить реальный домен теперь одна переменная окружения, не правка кода | — | Готово |
| ~~Refund failure только логируется~~ | Medium (финансовый риск) | ✅ **Сделано 2026-08-28** — `Payment.refundFailureReason`, персистится до throw (`noRollbackFor`). Видно через `GET /bookings/{id}/payments`; отдельный admin-list всех проблемных refund'ов — по-прежнему часть Platform Dashboard (раздел 9, Phase 1), не сделано в этом заходе | Admin-list — Phase 1 | Ядро готово, обзор — нет |
| File upload без content-type валидации | Medium | Принимает любой файл, ключ — UUID (не угадать) | Ограничить allow-list по MIME/расширению для фото | Рекомендовано, не жёсткий блокер для малого доверенного пилота |
| Модерация бизнеса не в audit log | Low-Medium | Только catalog-действия и создание platform-admin логируются | Добавить `auditLogService.record` в `ProviderController.updateStatus` | Желательно, не блокер |
| Два параллельных admin-контура (обычный ADMIN vs platform-admin) | Low-Medium (архитектурная путаница, не найдена прямая дыра) | Оба по отдельности корректно проверены | Прояснить границу или объединить в будущем | Нет, technical debt (раздел 17) |
| Нет revocation для access-токена | Low | Stateless JWT, TTL 30 мин | Стандартно для этой формы дизайна | Нет |
| SQL injection | — | Все native queries параметризованы (`:paramName`) | — | Чисто, действий не требуется |
| Sensitive data в логах | — | Не найдено ни одного случая | — | Чисто |

---

## 13. Phase 0 — Pilot Blockers

Порядок ниже учитывает реальные зависимости (Payment Provider Decision должен случиться до 0.1–0.4 обретут конкретную форму, но state-machine можно спроектировать provider-agnostic заранее — collections выше это и делают).

### 0.1 Payment domain hardening
- **Objective**: подготовить домен Booking/Payment к асинхронному провайдеру до его выбора.
- **Backend changes**: `BookingStatus.PENDING_PAYMENT`; `Payment` получает `refundAttempts`/`lastRefundError`; `Booking.cancel()` — новое обязательное поле причины.
- **DB changes**: миграция на новый статус-значение (enum как varchar — не требует schema-изменения самой колонки), новые nullable-колонки на `payment`.
- **API changes**: `POST /bookings/{id}/cancel` требует `reason` в теле.
- **Dependencies**: нет (может идти первым, не блокируется выбором провайдера).
- **Acceptance criteria**: существующие тесты (`BookingApiTests` и смежные) зелёные с новым статусом; отмена без причины — 400.
- **Complexity**: M. **Risk**: низкий — чисто аддитивное изменение, тот же паттерн backward-compat конструкторов, что уже используется в кодовой базе (см. `CreateAvailabilitySlotRequest`).

### 0.2 Provider integration
- **Objective**: заменить `MockPaymentProvider` реальной реализацией.
- **Backend changes**: новый класс в `payment-provider` модуле, реализующий существующий `PaymentProvider`; интерфейс, вероятно, потребует расширения под async-форму ответа `charge()` (redirect/token вместо булева результата).
- **Dependencies**: Payment Provider Decision (раздел 19).
- **Acceptance criteria**: реальная тестовая транзакция в sandbox-режиме провайдера проходит end-to-end.
- **Complexity**: L. **Risk**: самый высокий риск во всём Phase 0 — первая реальная внешняя интеграция в проекте, включая настоящие сетевые сбои, которых мок никогда не имитировал.

### 0.3 Webhook
- **Objective**: принимать асинхронное подтверждение оплаты.
- **Backend changes**: новый контроллер + provider-specific signature verification + идемпотентная обработка (dedup по event id).
- **API changes**: новый публичный (но подписанный) эндпоинт `POST /webhooks/payments/{provider}`.
- **Dependencies**: 0.2.
- **Acceptance criteria**: повторная доставка одного и того же webhook-события не меняет состояние дважды; невалидная подпись отклоняется.
- **Complexity**: L. **Risk**: высокий — тонкая логика (реплеи, гонки между webhook и sweep-job), требует реального тестирования, не только юнит-тестов.

### 0.4 Booking/Payment state machine
- **Objective**: связать webhook-результат с состоянием брони.
- **Backend changes**: `PaymentWebhookProcessor` → `PaymentsService` → транзакционный переход `Booking` в CONFIRMED/остаётся PENDING_PAYMENT; новый `@Scheduled` sweep job (по образцу `SubscriptionRenewalJob`).
- **Dependencies**: 0.1, 0.3.
- **Acceptance criteria**: заброшенная неоплаченная бронь автоматически отменяется через настраиваемый интервал, слот освобождается.
- **Complexity**: M.

### 0.5 Maps provider
- **Objective**: реальная карта на клиенте.
- **Mobile changes**: новая `MapRenderer`-абстракция в `apps/user_app/lib/features/maps/`, реализация под выбранный SDK, `DeviceLocationService` вместо мока.
- **Dependencies**: Map Provider Decision (раздел 19).
- **Acceptance criteria**: пользователь видит реальную карту с реальным местоположением и реальной дистанцией до провайдера.
- **Complexity**: M. **Risk**: низкий — backend не меняется вообще (раздел 6).

### 0.6 No-show/cancellation
- **Objective**: закрыть booking-lifecycle пробел.
- **Backend changes**: новое поле/статус no-show на `Booking`, новый эндпоинт для владельца пометить неявку.
- **Mobile changes**: UI в `business_admin` для пометки no-show на карточке брони.
- **Dependencies**: нет, может идти параллельно с 0.1.
- **Acceptance criteria**: владелец бизнеса может пометить прошедшую бронь как no-show; это отражается в `provider-insights` метриках отмен.
- **Complexity**: S-M.

### 0.7 Subscription billing (реальный провайдер)
- **Objective**: подписка бизнеса тоже через реальные деньги.
- **Backend changes**: минимальны — `SubscriptionRenewalService`/`SubscriptionService` уже используют тот же `PaymentProvider` bean, просто подключается та же новая реализация из 0.2.
- **Dependencies**: 0.2.
- **Acceptance criteria**: апгрейд на PRO — реальное списание, ежедневный renewal-job реально продлевает подписку.
- **Complexity**: S — это самая дешёвая часть Phase 0 именно потому, что архитектура уже разделяет провайдер и потребителя правильно.

### 0.8 Docker
- **Objective**: физическая возможность деплоя.
- **Infrastructure changes**: `./gradlew :platform-api:bootBuildImage`, проверка образа локально.
- **Dependencies**: нет.
- **Acceptance criteria**: образ поднимается с внешней БД/MinIO через env-переменные, `/actuator/health` отвечает 200.
- **Complexity**: S.

### 0.9 Staging + secrets
- **Objective**: первое реальное окружение.
- **Infrastructure changes**: hosting-target (решение — раздел 19), managed Postgres, все секреты как env-переменные, реальный CORS-origin.
- **Dependencies**: 0.8.
- **Acceptance criteria**: staging доступен по реальному URL, ни один секрет не в git-истории.
- **Complexity**: M.

### 0.10 Android release signing + rate limiting
- **Objective**: закрыть оставшиеся блокеры дистрибуции и безопасности.
- **Mobile changes**: реальный keystore для обеих аппок, секреты подписи как GitHub Secrets (уже подготовлено в `build-artifacts.yml`, просто не подключено).
- **Backend changes**: простой rate-limiter на auth-эндпоинты.
- **Dependencies**: нет, может идти в любой момент параллельно.
- **Acceptance criteria**: `flutter build apk --release` не debug-подписан; N неудачных логинов подряд блокируются.
- **Complexity**: S.

---

## 14. Phase 1 — Customer Experience

Делает пилот приятным и заслуживающим доверия, не только функциональным.

- **Real map rendering** — если не попало в Phase 0 по срокам.
- **Booking-reminder уведомление** (за час до брони) + payment-success/refund-уведомления клиенту (сегодня есть только для booking confirm/cancel и subscription fail).
- **Ответ бизнеса на отзыв** — управление репутацией сейчас невозможно в принципе.
- **Platform Dashboard v1** — Users/Businesses/Subscriptions/Bookings/Payments/Revenue-MRR, всё live-query (раздел 9), без новой модели данных.
- **Failed-refund видимость для админа** — финансовый риск, логичнее не откладывать глубоко в Phase 1, но технически не блокирует первую транзакцию.
- **Базовый 1:1 текстовый чат бизнес↔клиент** — пограничный случай между Phase 1 и Can Wait; «расширенный» (медиа, групповые треды) — точно Can Wait, но простое текстовое сообщение — самый заметный ежедневный gap удобства из всех найденных, стоит явного решения продукт-овнера, не default в Can Wait.

---

## 15. Phase 2 — Growth

- Полная событийная модель (`analytics_event` + недостающие publish-точки, раздел 10) + conversion funnel на дашборде.
- Business Dashboard v2 (тренды по времени, разбивка по сотрудникам).
- Промокоды / скидка на первый визит.
- Геокодирование адреса (если ручной ввод lat/lng окажется болью при росте числа бизнесов).
- Push-уведомления (FCM) — оправданы с реальным объёмом пользователей.
- Crash reporting (Sentry/Crashlytics).
- DAU/WAU/MAU на дашборде (зависит от event-модели).

---

## 16. Phase 3 — Scale

- Полноценный APM/мониторинг (Prometheus/Sentry APM) сверх health-check.
- Production-окружение отдельно от staging, если ещё не разделены.
- Reconciliation job (Payment vs provider) — оправдан объёмом, не раньше.
- Пересмотр multi-tenant isolation — **только** если появится реальный триггер по ADR-0004 (белый лейбл/комплаенс-требование конкретного клиента), не «на всякий случай».
- Вторая страна / мультивалютность (Phase D/E country-архитектуры, уже спроектированы, ждут триггера).
- Advanced loyalty/recommendations.

---

## 17. Technical Debt

Работает, но со известной ценой — не блокирует пилот, но стоит держать в поле зрения:

- **Два параллельных admin/authority контура** — обычная роль `ADMIN` (auth/users) для модерации бизнеса и совершенно отдельная система `platform-admin` (свой JWT-секрет, свой логин) для остального. Оба по отдельности корректны, но это две системы там, где по смыслу одна — стоит либо объединить, либо явно задокументировать границу, чтобы будущий разработчик не удивился.
- **`LoggingEmailNotificationProvider` как постоянная заглушка** — не проблема сама по себе (тот же паттерн, что и `MockPaymentProvider`), но пока не заменена, ни одно email-уведомление реально не доходит.
- **Отсутствие backend `MapProvider`-абстракции** — сегодня не нужна (Haversine provider-agnostic), но если когда-нибудь понадобится backend-геокодирование через платный API, точки подмены пока нет.
- **Узкое покрытие audit log** — самое чувствительное административное действие (модерация бизнеса) сегодня не аудируется.
- **Refund failure = только `log.error`** — тихий финансовый риск, уже учтён в Phase 0 (0.1), но стоит явно назвать техдолгом, а не просто gap: паттерн «залогировать и забыть» использован и для email-провайдера тоже — если это станет привычкой команды, стоит явно решить, что критичные для денег ошибки так обрабатывать нельзя.

---

## 18. Risks

- **Выбор платёжного провайдера может потребовать юрлица/эквайринг-договора** — если выбор падёт на провайдера без прямой поддержки Казахстана, интеграция может растянуться на недели сверх технической части. Это решение — раздел 19, но стоит понимать: это не только техническая задача.
- **Webhook-интеграция (0.3) — самая сложная новая часть кода во всём плане**. Идемпотентность, повторная доставка, гонка между webhook и sweep-job — легко ошибиться тонко (двойное списание, «зависшая» бронь). Стоит закладывать реальное время на end-to-end тестирование в sandbox-режиме провайдера, не только юнит-тесты.
- **Vendor lock-in по картам/платежам для Казахстана** — выбор локального провайдера может ограничить будущую экспансию за пределы страны; явное архитектурное решение, не случайность (см. многопровайдерную архитектуру в разделе 5, если потребуется split).
- **Объём работы Phase 0 нетривиален** — 10 пунктов, из которых минимум три (0.2, 0.3, 0.4) — это первая в проекте настоящая интеграция с внешней системой с реальными деньгами и реальной асинхронностью. Я сознательно не даю фейковых оценок в днях/неделях (раздел не содержит календарных чисел) — реальная скорость зависит от того, кто и сколько времени в неделю этим занимается, чего я не знаю и не должен придумывать.
- **Решение платёжного провайдера — единственная точка, блокирующая почти весь Phase 0** — чем раньше принято, тем раньше начинается измеримый прогресс; откладывание этого решения — самый дорогой риск в этом документе.

---

## 19. Decisions Required From Product Owner

Только то, что действительно нельзя решить по коду — не технические вопросы, на которые я мог ответить сам (и ответил, выше).

1. ~~**Payment provider**~~ — **решено: Kaspi Pay** (2026-08-28). Открытый технический вопрос, который это решение сразу поднимает: Kaspi Pay силён для разовых платежей (booking), но его пригодность именно для **recurring subscription-биллинга** (регулярное списание за PRO без участия пользователя каждый раз) нужно проверить отдельно, до начала п. 0.7 — это не то же самое, что разовый QR-платёж за бронь. Если recurring-биллинга через Kaspi нет или он неудобен, вариант — split-архитектура из раздела 5: Kaspi для booking-платежей, что-то ещё (или временно ручной инвойсинг) для подписки на старте пилота. Это первое, что стоит верифицировать перед 0.2/0.7.
2. **Map provider** — Google Maps (привычнее, дороже с ростом) vs Mapbox/OSM (дешевле/бесплатно, чуть больше настройки) vs 2ГИС (сильные локальные бизнес-данные в регионе, условия API нужно проверять отдельно).
3. ~~**Pilot country**~~ — **решено: Казахстан** (2026-08-28). Подтверждает допущение, на котором уже написан весь документ (валюта, `country`-запись в БД, выбор Kaspi Pay в п.1).
4. **First vertical для пилота** — beauty и auto одинаково production-ready функционально; фокус на одной вертикали для первого реального бизнеса, вероятно, снизит риск и объём поддержки на старте, но выбор — за тобой.
5. **Launch strategy** — мягкий запуск с 1-2 доверенными бизнесами (друзья/сеть контактов) для обкатки Phase 0 в реальных условиях, прежде чем открывать публично — или сразу публичный пилот?
6. **Infrastructure budget** — карта (платный API), hosting (staging + возможно production), комиссии Kaspi Pay — все три тянут за собой реальные ежемесячные расходы, которые нужно утвердить до выбора конкретного map-провайдера в п.2.

---

## 20. Final Recommended Execution Order

1. **Payment provider (Kaspi Pay) и pilot country (Казахстан) уже решены** — открывает путь к 0.2/0.7. Остаётся решение 2 (карты) — до него 0.5 не может начаться конкретно, но остальной Phase 0 уже разблокирован.
2. **Верифицировать recurring-биллинг через Kaspi Pay — первый шаг перед 0.2**, не после. Если окажется, что Kaspi не поддерживает удобный recurring для подписки — это меняет форму 0.7 (см. п.1 раздела 19), лучше узнать это до, а не в процессе интеграции.
3. ~~**0.6 (no-show/cancellation)**~~ — ✅ **сделано 2026-08-28**: cancellation reason + `NO_SHOW`-статус, с тестами (см. раздел 7). Обратите внимание: полноценный **0.1 (payment domain hardening = `PENDING_PAYMENT`)** сюда НЕ входит и намеренно отложен — его нельзя делать изолированно (см. правку выше в разделе 7): без всей webhook-цепочки (0.2–0.4) каждая бронь зависла бы в `PENDING_PAYMENT` навсегда, ничего её не подтверждало бы. Только refund-failure видимость (тоже часть 0.1) сделана отдельно — она аддитивна и безопасна сама по себе.
4. ~~**0.8 (Docker) и часть 0.9 (secrets externalization)**~~ — ✅ **сделано 2026-08-28**, включая живую проверку `docker run` против реальных Postgres/MinIO (раздел 11). Оставшаяся часть 0.9 (managed Postgres, реальный staging-хостинг) всё ещё ждёт — это уже не код, а инфраструктурная закупка.
5. **0.2 → 0.3 → 0.4 (Kaspi Pay → webhook → state machine) — строго последовательно**, самая рискованная и самая долгая цепочка, теперь разблокирована решением 1.
6. **0.5 (maps) — параллельно с 0.2–0.4**, независимая ветка работы, начинается сразу после решения 2.
7. **0.7 (subscription billing) — почти бесплатно после 0.2**, буквально то же интеграционное усилие, другая точка вызова (с оговоркой п.2 выше про recurring).
8. **0.10 (signing + rate limiting) — в любой момент**, ничем не заблокировано, можно делать в простое между другими шагами.
9. **Phase 1 начинается после того, как Phase 0 проверен на первой реальной, пусть небольшой, транзакции** — не раньше. Дашборд без реальных данных бессмысленен; уведомления о платеже без реального платежа проверить нельзя.

Один вопрос, на который должен отвечать весь этот документ: *что нужно, чтобы через несколько недель первый реальный бизнес мог зарегистрироваться, принимать реальные бронирования и деньги, а владелец платформы видел, что происходит* — ответ: **Phase 0, целиком, в порядке выше**, ничего меньше не даёт настоящего пилота, и почти ничего сверх Phase 0 не требуется для того, чтобы он состоялся.
