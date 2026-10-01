# ADR-0006: Freedom Pay Payment Integration

## Статус

Принято (discovery + design) — 2026-08-28. Реализовано (booking-платежи,
webhook, sweep-job, refund, каркас подписки) — тот же день, отдельный проход
после этого ADR. См. "Implementation Status" ниже — что реализовано как
спроектировано, что отличается, что всё ещё заблокировано.

## Implementation Status (2026-08-28)

Реализовано в этом проходе: `payment-provider`-модуль (`PaymentProviderName`,
переработанный `PaymentProvider`-порт, `MockPaymentProvider`, весь
`freedompay`-subpackage — `FreedomPayProperties`/`Config`/`Signature`/
`HttpClient`/`WebhookVerifier`/`Provider`/`OrderIds`), `Payment`/`PaymentStatus`
с новыми полями (`provider`, `idempotencyKey`, `providerStatus`, `checkoutUrl`,
`refundAttempts`, `@Version`), `Booking`/`BookingStatus.PENDING_PAYMENT` +
`BookingService.confirmAfterPayment`/`cancelUnpaidBooking`, `BookingPaymentTimeoutJob`
(sweep, каждую минуту), `PaymentWebhookController` + `PaymentWebhookProcessor`
+ `PaymentWebhookEventRecorder` + таблица `payment_webhook_event` (миграции
V29–V32), `SubscriptionCharge`/`SubscriptionService`/`SubscriptionRenewalService`
переведены на `createRecurringPayment`/`chargeRecurring`. Полностью зелёный
`./gradlew test` (mock-провайдер, весь существующий + новый test suite).

Отличия от того, что спроектировано выше:

- **`payment_webhook_event` — создана сейчас**, не просто обоснована. В
  discovery-фазе этого ADR было явно решено не создавать таблицу; отдельная
  задача на реализацию явно потребовала создать её сразу, с
  `unique (provider, event_id)`.
- **`@Version` добавлен и на `Booking`**, не только на `Payment` — "Webhook
  Architecture" выше называл только `Payment`. Понадобился отдельно для гонки
  webhook против `BookingPaymentTimeoutJob` (оба потенциально переводят один
  и тот же `Booking` из `PENDING_PAYMENT`).
- **Ответ на Result notify — без `pg_sig`**, хотя диаграмма выше рисует
  `<pg_sig>` в ответе. Точная семантика подписи ответа (а не только
  запроса) не подтверждена документацией — оставлено `TODO` в
  `PaymentWebhookController`, см. "Remaining Provider Questions".
- **Новый case, не предусмотренный таблицей переходов Booking**: успешный
  webhook приходит на уже `CANCELLED` бронь (sweep-job или клиент отменили
  раньше, чем пришло Result notify — "race F" из задачи на реализацию).
  Решение: `PaymentWebhookProcessor` автоматически вызывает
  `PaymentsService.refundPayment` вместо попытки подтвердить бронь — деньги
  списаны, подтверждать уже нечего (слот мог уйти другому клиенту).
- **`successUrl`/`failureUrl` — не в `payment.freedompay.*`**, а в общем
  `payment.return.*` — они не специфичны для Freedom Pay (Stripe потребовал
  бы того же), поэтому вынесены на уровень, который `payments`/`subscriptions`
  читают напрямую, не зная о Freedom Pay вообще (сохраняет границу
  "Booking/Subscription не знают деталей Freedom Pay" буквально).

## Context

`docs/PRODUCT_PRODUCTION_ROADMAP.md` (раздел 5) зафиксировал: и оплата брони, и
подписка бизнеса (FREE/PRO) сегодня идут через `MockPaymentProvider` —
синхронный, безусловно успешный, без единого сетевого вызова. Это
единственный настоящий блокер для реального пилота.

Продуктовые решения приняты (2026-08-28), в этом ADR не пересматриваются,
только их технические следствия:

- Страна пилота: Казахстан.
- **Основной платёжный провайдер: Freedom Pay** — и для оплаты брони, и для
  recurring-подписки бизнеса. *(Раньше в тот же день в разделе 19
  `PRODUCT_PRODUCTION_ROADMAP.md` было записано решение в пользу Kaspi Pay —
  это решение **заменено** данным. Обновил тот раздел отдельной правкой,
  см. отчёт после этого ADR.)*
- Будущий глобальный провайдер: Stripe — архитектура должна оставлять для
  него место, не блокировать.
- Первая вертикаль пилота: Beauty.
- Launch strategy: 1–2 реальных бизнеса.
- Карты — отдельная задача, не смешивается с этим ADR.

## Decision

Принять классический Freedom Pay `pg_*`-API (form-POST/XML, MD5-подпись) как
целевую интеграцию, не более новую `/v5/merchant/...` JWT-поверхность (см.
"Почему Freedom Pay" — обе существуют одновременно, это не мой выбор между
двумя одинаково зрелыми вариантами).

Сохранить `PaymentProvider` как порт (тот же принцип, что уже работает), но
расширить его форму под реальность: не синхронный `charge() → succeeded`, а
redirect-инициируемый платёж с подтверждением через webhook — форма, которую
сегодняшний интерфейс не может выразить.

**Recurring-списание подписки — не полностью подтверждено публичной
документацией** (см. "Открытые вопросы"). Решение — проектировать архитектуру
в предположении, что token-based recurring возможен (Freedom Pay явно
поддерживает создание recurring-профиля и хранение card-токена), но не
начинать реализацию 0.7 (subscription billing) до прямой проверки конкретного
запроса повторного списания — через мерчант-кабинет или поддержку Freedom
Pay. Это тот же принцип, что уже был записан в `PRODUCT_PRODUCTION_ROADMAP.md`
для Kaspi Pay, теперь применяется к реальному выбранному провайдеру.

## Why Freedom Pay

Это не переоценка продуктового решения — только техническая опора под него:

- Реальное присутствие в Казахстане, нативная поддержка KZT.
- **Hosted checkout снимает с Factory весь PCI-scope** — номер карты никогда
  не попадает на наш сервер, только `pg_redirect_url`, на который
  перенаправляется клиент. Это большая архитектурная экономия: не нужно
  ничего из PCI DSS Level-1/2 требований на нашей стороне.
- Подтверждённый `pg_idempotency_key` на создании платежа — ложится прямо на
  уже существующий паттерн (`PaymentProvider.charge(paymentId, ...)` уже
  использует `paymentId` как ключ идемпотентности, см. `PaymentsService`'s
  doc comment).
- Подтверждённый API возврата (`/revoke`), с оговоркой про фискальные данные
  (см. "Refund Architecture").

## Alternatives Considered

- **Kaspi Pay** — было записано как решение раньше в тот же день, заменено
  прямым продуктовым решением в пользу Freedom Pay. Не переоцениваю здесь
  почему — это решение владельца продукта, не техническое.
- **Stripe сейчас** — отклонено для пилота (уже отмечено в
  `PRODUCT_PRODUCTION_ROADMAP.md`: неопределённая поддержка Казахстана,
  вероятная необходимость иностранного юрлица). Остаётся явным будущим
  путём — см. "Future Stripe Integration".
- **Другие локальные агрегаторы** (PayBox, CloudPayments и т.п., упомянутые
  как общий класс в roadmap) — сняты с рассмотрения прямым продуктовым
  решением в пользу Freedom Pay.

## Booking Payment Architecture

```
Create Booking
      │  slot claimed atomically (уже работает — optimistic lock + unique index)
      ▼
PENDING_PAYMENT                              ← новый Booking-статус
      │
      ▼
POST /bookings/{id}/payments
      │  создаёт Payment(status=CREATED), вызывает FreedomPayProvider.charge(...)
      ▼
Freedom Pay: POST /init_payment
      │  pg_merchant_id, pg_amount, pg_currency, pg_order_id=booking-payment:{paymentId},
      │  pg_idempotency_key=paymentId, pg_success_url, pg_failure_url, pg_salt, pg_sig
      ▼
Response: pg_redirect_url                    ← hosted checkout, номер карты сюда, не к нам
      │
      ▼
Payment(status=PENDING) — API отдаёт checkout URL клиенту, дальше не ждёт
      │
      ▼
Клиент платит на стороне Freedom Pay (карта туда, не к нам — PCI-scope не наш)
      │
      ├──▶ Check request (до списания средств — pre-approval hook,
      │     см. "Webhook Architecture") — Factory может отклонить заказ здесь
      │
      ▼
Result notify (после списания) → POST /webhooks/payments/freedompay
      │  сигнатура проверена, платёж найден по pg_order_id
      ▼
Payment(status=SUCCEEDED | FAILED) + Booking(CONFIRMED | CANCELLED) — ОДНА транзакция
```

**Ключевой принцип, прямо из задачи**: **frontend redirect — не источник
истины**. `pg_success_url`/`pg_failure_url` — это просто куда браузер клиента
физически попадает после hosted checkout; страница на этом URL обязана
опрашивать `GET /bookings/{id}` (или дождаться реального статуса), а не
считать факт попадания на success-страницу подтверждением оплаты. Реальное
подтверждение — только верифицированный webhook, из раздела ниже.

**Отличие от сегодняшней архитектуры refund'а**: сегодня `BookingConfirmedEvent`
и refund-flow decoupled через `ApplicationEventPublisher` (ADR-0002) — это
осознанно **не повторяется** для перехода Payment→Booking здесь. Событийная
развязка хороша, когда неудача побочного эффекта не должна блокировать
основной коммит (неудачный refund не должен блокировать отмену брони — уже
так работает). Но переход "платёж подтверждён → бронь подтверждена" — это
ровно тот случай, который мы чиним: если это тоже сделать decoupled и
неатомарным, мы воссоздадим тот же баг, который вся эта работа устраняет.
Поэтому webhook-обработчик меняет `Payment` и `Booking` в одном
`@Transactional`-методе, не через отдельно публикуемое событие.

## Subscription Architecture

```
Business → POST /subscriptions/upgrade
      │  сегодня: синхронный paymentProvider.charge() прямо в HTTP-потоке —
      │  та же проблема, что и у booking-платежей, тем же способом чинится
      ▼
Create SubscriptionCharge(status=PENDING) + init_payment с
pg_recurring_start/pg_recurring_lifetime → создаёт recurring-профиль
      ▼
Response: pg_redirect_url — тот же hosted-checkout паттерн, что и у брони
      ▼
Клиент платит первый раз
      ▼
Result notify → pg_recurring_profile_id приходит в первом webhook'е
      │  ЭТО НУЖНО СОХРАНИТЬ — новое поле на SubscriptionCharge/Subscription,
      │  см. "Data Model"
      ▼
Subscription(status=ACTIVE), SubscriptionCharge(SUCCEEDED)

── Ежемесячно, из уже существующего SubscriptionRenewalJob ──

SubscriptionRenewalService.chargeForRenewal
      │  ⚠️ ТОЧНЫЙ запрос повторного списания по сохранённому
      │  pg_recurring_profile_id НЕ подтверждён в открытой документации —
      │  см. "Open Questions", п.1. Ниже — целевой flow В ПРЕДПОЛОЖЕНИИ,
      │  что такой запрос существует и работает как у аналогичных
      │  провайдеров (создать charge против сохранённого профиля/токена
      │  без повторного участия клиента).
      ▼
Freedom Pay: charge-by-profile (реальный endpoint — TBD)
      ▼
Webhook → SubscriptionCharge(SUCCEEDED) → Subscription.markRenewed()  [уже есть]
   ИЛИ
Webhook (или таймаут) → SubscriptionCharge(FAILED)
      ▼
Subscription.markPastDue(now, +7 days)  [уже есть, GRACE_PERIOD_DAYS=7 не меняется]
      ▼
   ┌─ повторное списание в течение grace удаётся → ACTIVE (renewal path выше)
   └─ grace истекает → downgradeToFree()  [уже есть, SubscriptionRenewalJob]
```

Существующая модель `Subscription`/`SubscriptionCharge`/`SubscriptionRenewalService`
**не меняется по форме** — `SubscriptionPlan`, `GRACE_PERIOD_DAYS=7`,
`downgradeToFree` (не блокирует существующие ресурсы ретроактивно) остаются
как есть, это уже правильно спроектировано. Меняется только *как* происходит
`paymentProvider.charge(...)` внутри — с синхронного на redirect+webhook, и
добавляется место для хранения `pg_recurring_profile_id`.

**Если п.1 "Open Questions" не подтвердится** (Freedom Pay не даёт чистого
API для списания сохранённого профиля) — запасной план для пилота на 1–2
бизнеса: полу-ручной биллинг (ежемесячный `init_payment` с новым
hosted-checkout redirect, отправленным бизнесу по email/уведомлению, не
настоящий off-session recurring). Это деградация, не blocker для пилота
именно такого масштаба (1–2 бизнеса), но must-confirm до полноценного роста.

## Webhook Architecture

Freedom Pay даёт **два разных hook'а**, не один:

1. **Check request** — до списания средств, позволяет Factory отклонить заказ
   (pre-approval). Не входит в диаграммы задачи явно, но реален и стоит
   использовать: например, если слот уже занят конкурентно между
   `init_payment` и оплатой (маловероятно благодаря optimistic lock, но
   Check request — бесплатная вторая линия защиты).
2. **Result notify** — после списания, окончательное подтверждение. Это то,
   что в задаче названо "webhook".

```
Freedom Pay
      │  POST на Result URL (настраивается в мерчант-кабинете, не обязательно
      │  передаётся per-request — нужно подтвердить, см. Open Questions)
      ▼
Подпись: MD5(script_name;поля-в-алфавитном-порядке-включая-pg_salt;secret_key)
      │  ⚠️ MD5, не HMAC-SHA256 — это ограничение провайдера, не наш выбор.
      │  Реализовать ТОЧНО по документации, не "усилить" самодеятельно —
      │  неправильная подпись просто не совпадёт с тем, что шлёт Freedom Pay.
      ▼
Найти Payment/SubscriptionCharge по pg_order_id
      │  Формат pg_order_id, который МЫ задаём при создании платежа:
      │  "booking-payment:{paymentId}" | "subscription-charge:{chargeId}"
      │  — так webhook-обработчик однозначно роутит без угадывания по таблицам
      ▼
Идемпотентность: Payment/SubscriptionCharge уже в терминальном статусе?
      │  ДА → всё равно ответить корректным XML-ACK (pg_status=ok), НЕ
      │       менять состояние повторно. Freedom Pay ретраит Result notify
      │       каждые 30 минут до 2 часов при неудачном ACK — если мы не
      │       подтверждаем правильно даже на повторной доставке, попытки
      │       продолжатся вхолостую.
      │  НЕТ → перейти в SUCCEEDED/FAILED, транзакционно перевести
      │       Booking/Subscription (см. выше)
      ▼
Ответ: XML <response><pg_status>ok</pg_status>...<pg_sig></response>, HTTP 200
```

**Важный нюанс, отличающий это от "стандартного" webhook-дизайна (Stripe-стиль
с `evt_...`)**: у Freedom Pay **нет отдельного уникального id доставки**
webhook'а — есть только `pg_payment_id`/`pg_order_id`, тот же на каждой
повторной попытке. Значит дедупликация **не может** опираться на "видели ли
мы этот event id раньше" — она опирается на "наш `Payment` уже в терминальном
статусе". `payment_webhook_event`-таблица (раздел "Data Model") в этой модели
— не первичный механизм дедупликации, а audit/observability слой.

Ответы на конкретные вопросы задачи:
- **webhook до frontend redirect** — нормально и ожидаемо, ничего не делает
  иначе.
- **webhook после закрытия приложения клиентом** — тоже нормально, обработка
  не зависит от живого клиента.
- **webhook дважды** — идемпотентность выше.
- **webhook не по порядку** — Check request по протоколу Freedom Pay всегда
  предшествует Result notify (не одновременные независимые события), реального
  риска переупорядочивания между ними нет. Риск, который есть: повторная
  попытка оплаты после FAILED создаёт новый `pg_payment_id` — нужно
  подтвердить, что `pg_idempotency_key` возвращает тот же id при ретрае с тем
  же ключом (Open Questions, п.5), иначе дедуп по `pg_order_id` может увидеть
  два разных `pg_payment_id` для одного нашего `paymentId`.
- **Concurrency** (два одновременных webhook-запроса на один платёж) — нужен
  `@Version` на `Payment` (сегодня отсутствует, есть только на
  `AvailabilitySlot`) — та же защита от гонки, что уже доказала себя для
  double-booking.

## Payment State Machine

**Не принимаю список из задачи автоматически** — вот что реально нужно
Factory с учётом настоящего Freedom Pay flow:

| Статус | Отличие от списка в задаче |
|---|---|
| `CREATED` | Строка создана, `init_payment` ещё не вызван (или вызов не подтверждён) — заменяет сегодняшнее поведение конструктора `Payment`, который ставит `PENDING` сразу при создании. |
| `PENDING` | `init_payment` успешен, есть `pg_payment_id`/`pg_redirect_url`, ждём Result notify. |
| ~~`REQUIRES_ACTION`~~ | **Не нужен.** У Stripe это отдельное состояние, потому что 3-D Secure — шаг, которым управляет *наш* клиент. У Freedom Pay весь этот шаг происходит внутри hosted checkout, целиком на их странице — Factory никогда не видит промежуточное "требует действия", только итоговый Result. Включение этого статуса создало бы состояние, в которое Factory никогда не сможет реально попасть. |
| `SUCCEEDED` | Как в задаче. |
| `FAILED` | Как в задаче — включает и явный отказ (`pg_result=0`), и таймаут sweep-джобы (см. `PRODUCT_PRODUCTION_ROADMAP.md`, тот же принцип, что уже был спроектирован для `PENDING_PAYMENT`-sweep). |
| `REFUND_PENDING` | Оставляю как защитный статус — не подтверждено, синхронен ли `/revoke` в ответе или тоже webhook-подтверждаемый (Open Questions). Дешевле спроектировать состояние заранее, чем добавлять миграцию позже. |
| `REFUNDED` | Как в задаче. |
| `REFUND_FAILED` | Как в задаче — это то самое поле `refundFailureReason`, которое уже реализовано в этой сессии (см. `PRODUCT_PRODUCTION_ROADMAP.md`, раздел 5/12) для mock-провайдера; с реальным провайдером логика та же, просто причина отказа теперь настоящая. |

### Booking transitions

| From | Event | To | Allowed? |
|---|---|---|---|
| (нет) | `createBooking`, слот атомарно занят | `PENDING_PAYMENT` | ✓ (новое — сегодня сразу `CONFIRMED`) |
| `PENDING_PAYMENT` | Result notify: успех, подпись верна | `CONFIRMED` | ✓ |
| `PENDING_PAYMENT` | Result notify: отказ, подпись верна | `CANCELLED`, слот освобождён | ✓ |
| `PENDING_PAYMENT` | sweep-job: нет webhook'а за таймаут | `CANCELLED`, слот освобождён | ✓ |
| `PENDING_PAYMENT` | клиент отменяет до оплаты | `CANCELLED` | ✓ (новый case — `cancelBooking`'s guard сегодня принимает только `CONFIRMED`, нужно расширить) |
| `CONFIRMED` | клиент отменяет | `CANCELLED` + refund-событие | ✓ (уже есть) |
| `CONFIRMED` | владелец завершает | `COMPLETED` | ✓ (уже есть) |
| `CONFIRMED` | владелец отмечает неявку | `NO_SHOW` | ✓ (уже есть, эта сессия) |
| `CANCELLED`/`COMPLETED`/`NO_SHOW` | что угодно | — | ✗ (терминальные, без изменений) |

## Refund Architecture

```
Booking cancellation (CONFIRMED, оплачена)
      ▼
BookingCancelledEvent  [уже есть, ADR-0002, decoupled — здесь ЭТО остаётся
                         правильным: неудачный refund не должен блокировать
                         сам факт отмены брони]
      ▼
BookingCancelledPaymentListener → PaymentsService.refundPayment
      ▼
Freedom Pay: POST /revoke
      │  pg_merchant_id, pg_payment_id, pg_refund_amount (0/omit = полный)
      │  ⚠️ + pg_receipt_positions[...] — фискальные данные чека (Казахстан,
      │  требования ККМ). Factory сегодня НЕ хранит позиции чека нигде —
      │  Payment знает только итоговую сумму, не строки "услуга/цена/налог".
      │  Реальный gap данных, не техническая мелочь — см. "Open Questions".
      ▼
Успех → Payment(REFUNDED)          [уже реализовано в этой сессии]
Неудача → Payment(SUCCEEDED, refundFailureReason=...)
      │   [уже реализовано — noRollbackFor, персистится до throw]
      ▼
Видимость для admin (не только log.error) — уже часть Phase 0 этой сессии,
не нужно переделывать, только подключить настоящего провайдера снизу.
```

Требование задачи "не `log.error()` → и всё" уже выполнено на уровне модели
данных (сделано раньше в этой же сессии, до этого ADR) — реальный провайдер
подключается под ту же структуру, не требует нового дизайна отказоустойчивости.

**Обновлено (2026-09-18)**: диаграмма выше описывает состояние ДО durable
refund outbox — `BookingCancelledPaymentListener` действительно вызывал
`PaymentsService#refundPayment` напрямую, best-effort, только логируя отказ.
Это заменено durable outbox-flow — см. новый раздел "Durable Refund Outbox"
ниже для актуальной архитектуры. `PaymentsService#refundPayment` сам по себе
не изменился и остаётся тем же синхронным admin-triggered retry-путём,
который эта диаграмма всё ещё корректно описывает для `POST /payments/
{id}/refund`.

## Durable Refund Outbox (2026-09-18)

Отдельная задача: у отменённой оплаченной Booking возврат не должен зависеть
от того, был ли процесс приложения жив в момент вызова `PaymentProvider
#refund`. До этого прохода `BookingCancelledPaymentListener` делал ровно это
(запуск на `AFTER_COMMIT` + `REQUIRES_NEW`, вызов `PaymentsService
#refundPayment` напрямую, отказ — только `log.error`, без retry) — то же
семейство бага, которое Phase 0 уже закрыл для loyalty earning (см. выше в
этом документе). Реализовано теми же принципами: durable outbox-таблица
(`payment_refund_request`, `V63`), заполняемая **в той же транзакции**, что
и факт, требующий возврата, плюс отдельный retrying worker.

### Lifecycle и transaction boundaries

```
BookingService#cancelBooking (@Transactional)
      │  booking → CANCELLED, слот освобождён
      ▼
BookingCancelledPaymentListener (plain @EventListener, joins эту же
транзакцию — НЕ AFTER_COMMIT)
      │  если у Booking была SUCCEEDED Payment:
      │  создаёт PaymentRefundRequest(status=PENDING) + Payment → REFUND_PENDING
      │  — атомарно с cancelBooking: либо оба коммита, либо ни одного
      ▼
commit
      │
      ▼
PaymentRefundOutboxProcessor.onRefundRequestReady (@TransactionalEventListener
AFTER_COMMIT) — eager nudge, latency-оптимизация для типичного случая, не
единственный механизм durability (см. ниже)
      ▼
PaymentRefundOutboxItemProcessor#claim (REQUIRES_NEW, PESSIMISTIC_WRITE lock)
      │  PENDING/RETRY(due)/PROCESSING(stale) → PROCESSING, commit
      ▼
PaymentProvider#refund(...)   ← ВНЕ любой транзакции, здесь и только здесь
      │
      ├─ success → applySuccess (REQUIRES_NEW): PaymentRefundRequest →
      │  SUCCEEDED (terminal), Payment → REFUNDED, publish PaymentRefundedEvent
      │  (тот же event, что loyalty/notifications уже слушают — без изменений
      │  там)
      └─ failure/exception → applyFailure (REQUIRES_NEW): attempts += 1,
         status → RETRY, nextAttemptAt = now + backoff(attempts); при
         attempts >= MAX_ATTEMPTS (8) → FAILED (terminal) + Payment →
         REFUND_FAILED (та же admin-видимость, что и manual retry failure)
```

Второе место, создающее `PaymentRefundRequest` той же схемой — `race F` в
`PaymentWebhookProcessor#applyTransition` (поздний webhook подтверждает
оплату для уже `CANCELLED` booking): транзакция там уже открыта
(`@Transactional`, не decoupled событием — как и раньше, см. "Webhook
Architecture" выше), так что запись коммитится атомарно с `payment
.markSucceeded`.

**Почему сам provider-call вне транзакции**: durable-запись обязана быть
атомарной с cancellation; сетевой вызов к Freedom Pay — нет, и не должен
держать открытую транзакцию (и, что важнее, row lock) на всё время сетевого
таймаута.

### States

`PENDING` → `PROCESSING` → (`SUCCEEDED` | `RETRY` → `PROCESSING` → ... |
`FAILED`). `SUCCEEDED`/`FAILED` — terminal, `PaymentRefundRequest#isClaimable`
возвращает `false` для обоих безусловно — ни retry, ни повторный provider-call
после `SUCCEEDED` невозможны в принципе (не просто "маловероятны").

### Retry policy

Экспоненциальный backoff (30s, 60s, 120s, 240s, 480s, 960s, capped 1800s),
`MAX_ATTEMPTS = 8` — сознательно НЕ плоский retry каждые 15s, как у
`loyalty.LoyaltyOutboxProcessor` (там retry — дешёвая идемпотентная
рекомпьютация; здесь — реальный сетевой вызов к внешнему платёжному
провайдеру, долбить который каждые 15s при устойчивом сбое не помогает
никому). Sweep (`@Scheduled(fixedDelay = 15_000)`) сам по себе работает на
реальном wall-clock времени — backoff только решает, due ли конкретная
строка на момент очередного прохода sweep.

### Idempotency

Три независимых уровня:
1. **`payment_id unique`** (V63) — у одной Payment не может существовать
   двух `PaymentRefundRequest` строк одновременно. Дубликат
   `BookingCancelledEvent` (в норме невозможен — `cancelBooking`'s guard
   делает отмену one-time transition) упал бы на этом constraint, откатив
   всю транзакцию отмены — безопасный, а не тихий отказ.
2. **`PESSIMISTIC_WRITE`-лок на claim** (`PaymentRefundRequestRepository
   #lockById`) — тот же механизм, уже доказанный корректным для
   `loyalty.LoyaltyRedemptionRepository#lockById` (см. `LoyaltyApiTests
   .onlyOneOfTwoConcurrentRedemptionsForANearlyExhaustedBalanceSucceeds`).
   Два конкурентных worker'а (или eager nudge, racing со scheduled sweep
   за одну и ту же строку) не могут оба увидеть claimable-статус до того,
   как один из них закоммитит `PROCESSING`.
3. **`SUCCEEDED`/`FAILED` terminal** — `applySuccess`/`applyFailure` оба
   перепроверяют `status == PROCESSING` под тем же локом перед тем, как
   что-либо менять; повторный вызов на уже разрешённую строку — no-op.

### Restart recovery

`processing_started_at` + `STALE_PROCESSING_THRESHOLD` (5 минут, дольше
15s-таймаута `FreedomPayHttpClient`) — строка, оставленная в `PROCESSING`
крашнувшимся воркером, становится claimable снова после порога (см.
`PaymentRefundRequest#isClaimable`, покрыто
`PaymentRefundRequestTest.staleProcessingBecomesClaimableAgainPastTheThreshold_restartRecovery`).
`PENDING`/`RETRY` строки просто переживают restart как обычные committed
DB-строки — их не нужно "восстанавливать", они уже durable.

### Provider-timeout / double-refund: подтверждённое ограничение, не выдумка

**Freedom Pay's `/revoke.php` не несёт собственного confirmed idempotency-
ключа** (в отличие от `pg_idempotency_key` на создании платежа — см.
"Idempotency" выше в этом документе) — ADR-0006's Open Questions #3/#5 уже
фиксировали, что этот вопрос открыт. Значит: если сетевой вызов к `/revoke
.php` оборвался по таймауту (или воркер упал прямо во время запроса) и
Factory не получила structured-ответ — этот код **не может достоверно
отличить** "Freedom Pay точно не выполнила возврат" от "Freedom Pay возврат
выполнила, но ответ потерян". Обе ветки (пойманное исключение из
`paymentProvider.refund`, и структурный `RefundResult(false, ...)`)
трактуются одинаково — retry до `MAX_ATTEMPTS` — потому что альтернатива
("не ретраить при неопределённости") рискует навсегда не вернуть деньги
клиенту, а это хуже управляемого, ограниченного (8 попыток) риска
повторного списания. Это тот же класс ограничения, что и `chargeRecurring`
(см. "Follow-up" выше) — снимается только прямым доступом к merchant-
кабинету/поддержке Freedom Pay, не кодом. Не добавлен reconciliation-вызов
через `getPaymentStatus` перед retry: этот endpoint подтверждённо
возвращает только `pg_result` (success/failure/pending для ПЛАТЕЖА), не
задокументированное поведение специфично для возврата — использовать его
как "подтверждение уже выполненного возврата" было бы тем самым
угадыванием контракта, которого эта задача явно требует избегать.

### Диагностика FAILED-строки

`GET /api/v1/platform/payments/refund-requests?status=FAILED`
(`PaymentAdminController`) — attempts, lastError, provider/providerReference,
createdAt/updatedAt для каждой dead-lettered строки. Тот же Payment также
попадает в уже существующий `GET .../failed-refunds` (`status=
REFUND_FAILED`) и его существующий manual retry (`POST /payments/{id}
/refund`) — так что FAILED-строка не тупик: human operator может
подтвердить состояние в Freedom Pay's мерчант-кабинете и вручную повторить
через уже существующий admin-эндпоинт.

## Idempotency

Два **разных** механизма, которые легко перепутать:

1. **Исходящая идемпотентность** (наш повторный вызов `init_payment`, если наш
   же сетевой вызов упал) — `pg_idempotency_key = payment.getId()`. Это уже
   ровно то, что `PaymentProvider.charge(paymentId, ...)` делает сегодня —
   **интерфейс не меняется** для этой части, только реализация.
2. **Входящая защита от повтора webhook'а** — не по ключу идемпотентности, а
   по проверке "уже терминальный статус?" (см. "Webhook Architecture") —
   потому что у Result notify нет отдельного event-id, только тот же
   `pg_payment_id` на каждой из до 4 повторных попыток.

## Security

- **Подпись** — MD5, как задокументировано Freedom Pay. Не "усиливать"
  собственной криптографией — это гарантированно сломает совместимость;
  ограничение провайдера, реализовать точно.
- **Секреты** — `pg_merchant_id` + один `secret_key`, который используется
  **и** для подписи исходящих запросов, **и** для проверки входящих
  webhook'ов. Это значит один скомпрометированный секрет даёт обе
  возможности (подделать запрос к Freedom Pay от нашего имени, и подделать
  webhook Freedom Pay → нам) — максимально чувствительное значение,
  `${FREEDOMPAY_SECRET_KEY}`, только env var/secrets manager, никогда не в
  git (тот же принцип, что уже применён к JWT-секретам в этой сессии).
- **Никогда не доверять amount/currency/status от клиентского приложения** —
  явное требование задачи, уже архитектурно естественно: клиент никогда не
  отправляет сумму или статус Factory напрямую — единственный источник этих
  значений после создания платежа — верифицированный webhook. Не нужен
  отдельный защитный код "против клиента", потому что клиент физически не
  участвует в этой части flow (весь ввод данных — на стороне Freedom Pay).
- **Replay-атаки** — покрыто идемпотентностью по статусу выше; отдельно
  стоит **сверять `pg_amount`/`pg_currency` из webhook с тем, что хранится в
  нашем собственном `Payment`** при обработке — расхождение (даже с верной
  подписью) значит либо баг, либо более сложная атака — логировать как
  аномалию, не молча принимать webhook'а как источник суммы.
- **Order ID spoofing** — `pg_order_id` должен резолвиться в реально
  существующий `Payment`/`SubscriptionCharge`, который Factory сама создала;
  неизвестный id — отклонить, не создавать ничего по webhook'у "с нуля".

## Data Model

*(Не создаю миграции — только предложение, по явному запросу.)*

**`payment`**:
- `provider` (varchar/enum: `MOCK` / `FREEDOMPAY` / будущий `STRIPE`) — новое.
  Сегодня колонки нет вообще, потому что провайдер всегда был один.
- `version` (`@Version`, integer) — новое, защита от гонки конкурентных
  webhook-доставок (см. "Webhook Architecture").
- `provider_reference` — **уже существует**, ничего не менять, просто теперь
  реально хранит `pg_payment_id`.
- `refund_failure_reason` — **уже существует** (эта сессия).
- Позиции чека для refund (`pg_receipt_positions`) — **не проектирую
  конкретную схему сейчас**, это открытый вопрос данных, не только
  архитектуры (см. "Open Questions", п.4) — возможно, достаточно составлять
  их на лету из `ServiceOffering` в момент refund, не хранить отдельно.

**`subscription_charge`**:
- `provider` — то же новое поле, что и у `payment`.
- `recurring_profile_id` (nullable varchar) — новое, реально нужное:
  `pg_recurring_profile_id` приходит только в первом webhook'е создания
  профиля, должно быть где-то сохранено для последующих списаний.
- `provider_reference` — уже существует.

**`payment_webhook_event`** (`provider`, `payment_id`, `received_at`,
`processed_at`, `status`, `payload_hash`) — **обоснование, не создаю
таблицу**: нужна не как первичный механизм дедупликации (см. "Webhook
Architecture" — та роль у status-check на самом `Payment`), а как:
(а) audit-лог для расследования спорных платежей/возвратов — реальные деньги,
реальный бизнес будет спрашивать "почему бронь не подтвердилась", это первое
место для ответа; (б) защита от replay за пределами дедупликации по статусу
— если один и тот же payload приходит с другой подписью/содержимым уже
после того, как `Payment` терминален, это стоит зафиксировать как аномалию,
а не просто молча проигнорировать. Оправдано, но не блокирует дизайн
остального — можно добавить отдельным шагом реализации.

## Testing Strategy

**Unit**:
- Вычисление и проверка MD5-подписи — чистая функция, тестируется по
  известным примерам из документации Freedom Pay (детерминированный
  input/output, не нужен реальный API).
- Guard'ы переходов состояния (`Payment`/`Booking`/`SubscriptionCharge`) —
  так же, как уже тестируются существующие переходы в `BookingApiTests`.
- Идемпотентность webhook (терминальный статус → no-op, но корректный ACK).

**Integration**:
- `FreedomPayProvider` против поднятого локально фейкового HTTP-сервера,
  имитирующего реальные `pg_*`-ответы (WireMock или эквивалент) — не против
  настоящего Freedom Pay.
- Postgres через Testcontainers — тот же паттерн, что уже используется
  везде в `platform-api`.
- Webhook-эндпоинт целиком — реальная подпись, реальный XML parse/response.
- Транзакционные границы — тест, что конкурентные webhook-запросы на один
  `Payment` не производят двойной эффект (эксплуатирует `@Version` выше).

**Sandbox E2E** — помечаю как **заблокировано открытым вопросом**: не
подтверждён отдельный sandbox-хост (см. "Open Questions", п.2) — до
прямого доступа к мерчант-кабинету Freedom Pay нельзя написать реальный
E2E-прогон "бронь → Freedom Pay sandbox → webhook → confirmed" с
уверенностью, что это не бьёт по продакшену.

## Environment Strategy

```
local   → MockPaymentProvider   (без изменений — ноль риска для
test    → MockPaymentProvider    существующего test suite, вся текущая
                                  сессия тестов остаётся зелёной как есть)
staging → FreedomPayProvider (testing mode — механизм sandbox не
                               подтверждён, см. Open Questions п.2)
production → FreedomPayProvider (live)
```

Выбор бина — через конфигурацию (`payment.provider: mock|freedompay`,
`@ConditionalOnProperty`), не профили Spring напрямую — соответствует
единственному существующему прецеденту выбора реализации в этом кодбейсе
(`TestPayments`'s `@Primary`-подмена в тестах уже делает похожее для тестового
контекста).

## Future Stripe Integration

`PaymentProvider`-порт уже сегодня рассчитан на вторую реализацию (см.
`PRODUCT_PRODUCTION_ROADMAP.md`, раздел 5 — "смена мока на реальный провайдер
технически — это одна новая реализация интерфейса"). Redirect+webhook формат,
который вводит этот ADR под Freedom Pay, — это **тот же формат**, который
нужен Stripe (PaymentIntents тоже асинхронны, тоже webhook-подтверждаемы).
Ирония в том, что Stripe's модель состояний чище и лучше задокументирована,
чем Freedom Pay's — спроектировав под более сложный/менее документированный
случай сейчас, Stripe позже добавляется легче, не наоборот.

Единственное, что специфично для Freedom Pay и **не должно** просачиваться
в общий интерфейс: MD5-подпись, XML-ответ на webhook, двухфазный
Check+Result — всё это остаётся внутри `FreedomPayProvider` и его
webhook-обработчика, `PaymentProvider`-порт остаётся про "создать платёж,
вернуть возврат", не про механику конкретного провайдера.

## Risks

- **Recurring-списание не подтверждено публичной документацией** — самый
  большой риск, блокирует именно 0.7 (subscription billing) конкретно, не
  booking-платежи.
- **Фискальные данные чека на refund** — может заблокировать refund flow,
  если Factory не сможет их корректно составлять на момент запроса.
- **MD5** — криптографически устаревший алгоритм, но это требование
  провайдера, не то, что Factory может решить иначе.
- **Sandbox-механизм не подтверждён отдельно от продакшена** — риск
  тестирования вплотную к реальным деньгам, если `pg_testing_mode` работает
  не так, как предполагается.
- **Два несовместимых API-поколения у самого Freedom Pay** (классический
  `pg_*` и новый `/v5/merchant` с JWT+AES) — намекает, что провайдер может
  быть в процессе миграции; их публичное поведение может измениться без
  предупреждения Factory.
- **Объём работы** — то же предупреждение, что и в `PRODUCT_PRODUCTION_ROADMAP.md`
  (раздел 18): это первая настоящая интеграция с реальным внешним платёжным
  провайдером в проекте, с реальной асинхронностью — не оценивать в днях
  без реального исполнителя, планирующего своё время.

## Open Questions

Требуют прямого доступа к мерчант-документации/поддержке Freedom Pay, не
решаются по опубликованным материалам:

1. **Точный запрос повторного списания по `pg_recurring_profile_id`/
   card-токену** — не найден в открытой документации. Блокирует детальный
   дизайн 0.7 до подтверждения.
2. **Sandbox** — отдельный хост или `pg_testing_mode`-флаг на том же API?
3. **`/revoke` vs `/g2g/refund`** — какой актуальный endpoint для возврата,
   в чём разница.
4. **Фискальные позиции чека на refund** — обязательны ли всегда, откуда
   Factory их берёт (составлять на лету из `ServiceOffering` при отмене?).
5. **`pg_idempotency_key`** — гарантирует ли Freedom Pay тот же
   `pg_payment_id` при повторном вызове с тем же ключом, или создаёт новый
   каждый раз? Влияет на то, надёжен ли дедуп webhook'а по `pg_order_id`
   при повторной попытке оплаты после `FAILED`.
6. **Result URL** — настраивается только в мерчант-кабинете (статично), или
   можно передать per-request при `init_payment`? Влияет на то, нужен ли
   один глобальный `webhook-url` в конфигурации или что-то динамическое.

Ничего из этого не блокирует написание кода для booking-flow (раздел
"Booking Payment Architecture" не зависит ни от одного из этих пунктов) —
блокирует только: полноценный дизайн 0.7 (recurring), финальный выбор
refund-endpoint'а, и подтверждение sandbox-стратегии для E2E-тестов.

## Known Provider Limitations

Подтверждено кодом этого прохода, не только документацией:

- **`chargeRecurring` не реализован** — `FreedomPayProvider.chargeRecurring`
  всегда бросает `UnsupportedRecurringChargeException` (см. "Open Questions"
  п.1). `SubscriptionRenewalService` уже ловит это как обычный
  `RuntimeException` и переводит подписку в `PAST_DUE` — деградация
  предсказуема, не крэш, но повторное списание business-подписки **не
  работает** ни в staging, ни в production до подтверждения реального
  запроса от Freedom Pay.
- **Refund без фискальных позиций чека** — `FreedomPayProvider.refund`
  отправляет `pg_payment_id`/`pg_refund_amount`, не отправляет
  `pg_receipt_positions[...]`. Если реальный API их требует, refund будет
  честно приходить `RefundResult(false, ...)` → `Payment.REFUND_FAILED`
  (видимо для admin, не тихая потеря), но не будет работать до данных.
- **Endpoint возврата не подтверждён окончательно** — используется
  `/revoke.php` (единственный документированный вариант, который нашло
  исследование); альтернативный `/g2g/refund` не проверен и не
  реализован. Если `/revoke.php` окажется неверным для реального
  мерчант-аккаунта, refund будет предсказуемо и видимо проваливаться
  (`REFUND_FAILED`), не притворяться успешным.
- **Result URL** — предполагается статически настроенным в мерчант-кабинете
  (`payment.freedompay.result-notify-script-name`, по умолчанию
  `result.php`), не передаётся per-request в `init_payment`. Если Freedom
  Pay на самом деле поддерживает per-request result URL, а мерчант-кабинет
  настроен на другой script name — подпись входящего webhook'а не совпадёт
  (см. `FreedomPayWebhookVerifier`'s TODO), и легитимные webhook'и будут
  отклоняться до исправления конфигурации (не кода).

## Sandbox Configuration

Не подтверждено — нет доступа к мерчант-кабинету Freedom Pay в этой сессии.
Когда доступ появится, staging переключается без изменения кода, только
конфигурацией (env vars, ADR-0006's "Environment Strategy" уже это
предполагал):

```
PAYMENT_PROVIDER=freedompay
FREEDOMPAY_API_URL=<хост из мерчант-кабинета — sandbox или pg_testing_mode>
FREEDOMPAY_MERCHANT_ID=<sandbox merchant id>
FREEDOMPAY_SECRET_KEY=<sandbox secret key>
FREEDOMPAY_RESULT_NOTIFY_SCRIPT_NAME=<script name, настроенный в кабинете>
PAYMENT_SUCCESS_URL=<staging URL, куда возвращается браузер>
PAYMENT_FAILURE_URL=<staging URL>
```

Ни одно значение не имеет hardcoded default (специально, см.
`FreedomPayProperties`) — `FreedomPayProvider` фейлится при старте
приложения, если `FREEDOMPAY_API_URL` пуст, а `payment.provider=freedompay`
(fail fast, не тихий вызов в никуда).

## Production Configuration

Тот же набор переменных, что и Sandbox, со значениями продакшен
мерчант-аккаунта — `PAYMENT_PROVIDER=freedompay` в обоих случаях (staging и
production отличаются только *значениями* секретов/хоста, не кодом и не
веткой конфигурации). Секреты — только через переменные окружения/secrets
manager хостинга; ни один git-отслеживаемый файл (`application.yml`, тесты,
Flutter-код) не содержит реального `FREEDOMPAY_SECRET_KEY`/`MERCHANT_ID` —
проверено: единственные значения в репозитории — тестовые/примерные.

## Remaining Provider Questions

Статус исходных "Open Questions" после этого прохода реализации — ни один не
решился (нет доступа к мерчант-кабинету/поддержке), но теперь у каждого есть
конкретный код, который он блокирует:

1. Запрос повторного списания — блокирует `chargeRecurring`
   (`UnsupportedRecurringChargeException` пока).
2. Sandbox-хост/`pg_testing_mode` — блокирует Sandbox E2E, см. выше.
3. `/revoke` vs `/g2g/refund` — реализовано на `/revoke.php`, риск см. "Known
   Provider Limitations".
4. Фискальные позиции чека — не отправляются, риск см. выше.
5. `pg_idempotency_key`'s retry-семантика — не проверено вживую (нет sandbox
   доступа), дедуп webhook'а полагается на `Payment`-статус, не на это поле,
   так что риск ограничен дублирующимся списанием при клиентском ретрае
   после сетевой ошибки, не потерей дедупликации webhook'а.
6. **Новый вопрос, не в исходном списке**: подписывается ли ответ на Result
   notify (`pg_sig` в ответе, как рисует диаграмма "Webhook Architecture"
   выше), или `pg_status=ok` без подписи достаточно останавливает ретраи?
   Реализовано без подписи ответа — `PaymentWebhookController`'s TODO.

## Follow-up: chargeRecurring Confirmation Attempt (2026-09-18)

Отдельная задача: реализовать `FreedomPayProvider.chargeRecurring` по
подтверждённому контракту, либо, если контракт нельзя подтвердить —
зафиксировать конкретный blocker вместо угадывания. Результат этого
прохода: **контракт не подтверждён, `chargeRecurring` не реализован,
`UnsupportedRecurringChargeException` оставлен без изменений.**

**Что было предпринято:**
- Полный повторный разбор текущей интеграции (`FreedomPayProvider`,
  `FreedomPayHttpClient`, `FreedomPayProperties`, `FreedomPaySignature`,
  `SubscriptionRenewalService`, `SubscriptionCharge`, этот ADR) — без новых
  расхождений с кодом, всё по-прежнему соответствует описанному выше.
- Проверка репозитория на любые ранее не замеченные материалы (sandbox
  credentials, merchant-cabinet доступ, SDK-зависимость) — ничего не
  найдено: `payment-provider/build.gradle.kts` не подключает никакого
  FreedomPay SDK (чистый `java.net.http`, по дизайну), нет `.env.example`
  или CI-секретов с реальными/sandbox значениями `FREEDOMPAY_*`.
- Поиск в открытых источниках (WebSearch) по `docs.freedompay.kz` и
  зеркалам (`freedompay.kg`, `freedompay.uz`, `freedompay.money`) —
  **новая зацепка, не бывшая в первом проходе**: сниппеты поисковой
  выдачи (несколько независимых запросов, согласованно) указывают на
  метод с именем **`make_recurring_payment`** и параметром
  **`pg_recurring_profile`** (значение — тот самый `pg_recurring_profile_id`,
  который сегодня уже захватывается и сохраняется —
  `SubscriptionService.upgradeToPro` читает `result.recurringProfileId()`
  прямо из синхронного ответа `createRecurringPayment` (`init_payment.php`'s
  `pg_recurring_profile_id`, распарсенного в `FreedomPayProvider.initiate`)
  и сразу вызывает `SubscriptionCharge.assignRecurringProfileId` — не из
  Result notify webhook'а, как рисовала диаграмма "Subscription
  Architecture" выше изначально, но тот же результат: `recurring_profile_id`
  уже на месте и готов быть переданным как `pg_recurring_profile`, когда
  контракт `chargeRecurring` подтвердится).
- Прямой fetch первоисточника (`docs.freedompay.kz/folder-2444932`
  "Purchase", `docs.freedompay.kz/api-11620859` "Create payment",
  зеркала на `freedompay.kg`/`freedompay.money`) — **заблокирован
  egress-политикой этой сессии** (`EGRESS_BLOCKED`, все домены
  `freedompay.*` не в allowlist исходящего трафика). Это подтверждённое
  ограничение окружения (`/root/.ccr/README.md`: "403/407 — do not
  retry or route around it, report the blocked host"), не временный сбой.

**Почему это не считается подтверждением, достаточным для реализации:**
поисковые сниппеты — это агрегированные пересказы страниц, не сам текст
документации; они не дают (а) точный script-path (`make_recurring_payment`
без подтверждённого `.php`-суффикса и точного пути относительно
`api-url`, хотя это наиболее вероятная форма по аналогии с `init_payment.php`
и `revoke.php`), (б) полный список обязательных `pg_*`-полей запроса
(есть ли `pg_amount`/`pg_currency`/`pg_description`, как у остальных
вызовов — вероятно, но не процитировано напрямую), (в) форму ответа
(`pg_status`/`pg_result`, как у прочих вызовов — не процитировано), (г)
схему подписи для конкретно этого script-name (весь остальной API
подписан `MD5(script_name;поля;secret_key)` — по аналогии должно быть
так же, но не подтверждено для этого метода отдельно), (д) поведение при
повторном вызове (тот же контракт `pg_idempotency_key`, что и у
`init_payment`, или другой). Реализация платёжного кода, двигающего
реальные деньги, на пересказе поисковой выдачи вместо текста
первоисточника — ровно тот риск (тихий двойной charge или тихий silent
no-op), которого исходное решение `UnsupportedRecurringChargeException`
явно избегает (см. класс-левел doc comment `FreedomPayProvider`).

**Конкретный blocker и как его снять** (любой один из путей ниже
подтверждает контракт до уровня, достаточного для реализации):
1. Egress-доступ в этой или следующей сессии к `docs.freedompay.kz`
   (или зеркалам `freedompay.kg`/`freedompay.uz`/`freedompay.money`) —
   позволит напрямую прочитать страницу(ы) про recurring-списание и
   процитировать точный контракт вместо пересказа поисковика.
2. Доступ к merchant-кабинету Freedom Pay (sandbox или testing mode) —
   даёт возможность реально вызвать `make_recurring_payment` (или как он
   называется на самом деле) против тестового профиля и зафиксировать
   контракт по факту ответа, не по документации вообще.
3. Прямой ответ поддержки Freedom Pay на вопрос "точный запрос
   повторного списания по `pg_recurring_profile_id`" — тот же вопрос,
   что стоял в Open Questions #1 с самого начала этого ADR.
4. Человек с доступом к документации вставляет точный текст
   релевантной(ых) страниц в задачу — этого достаточно без сетевого
   доступа вообще.

**Что осталось нетронутым и почему это правильно:** `FreedomPayProvider.
chargeRecurring` продолжает бросать `UnsupportedRecurringChargeException`
без изменений в теле; `SubscriptionRenewalService` продолжает ловить это
как `RuntimeException` → `PAST_DUE` (уже корректно, не новый код).
Booking payment flow (`createPayment`, `getPaymentStatus`, `refund`,
webhook-обработка) не тронут вообще — эта задача была строго
scoped к `chargeRecurring`, изменений вне него нет.
