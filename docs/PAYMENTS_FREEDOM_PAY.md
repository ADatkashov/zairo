# Оплата бронирований через Freedom Pay

Практический обзор того, как в ZAIRO работает оплата услуг: от клика
клиента "Оплатить" до выплаты бизнесу. Подробное архитектурное обоснование
и то, что подтверждено документацией Freedom Pay, а что нет — в
[ADR-0006](adr/0006-payment-provider-freedompay.md) (платёж/webhook/refund)
и [ADR-0007](adr/0007-marketplace-commission-and-settlement.md) (комиссия/
выплата бизнесу/reconciliation). Этот документ — рабочая шпаргалка "как
это устроено сейчас", ADR — "почему именно так и что не подтверждено".

## 1. Как клиент платит

```
Booking (PENDING_PAYMENT, цена = ServiceOffering.price — клиент её не задаёт)
   ↓  POST /api/v1/bookings/{id}/payments
Payment(CREATED) → FreedomPayProvider.createPayment(...)
   ↓  Freedom Pay init_payment.php → pg_redirect_url (hosted checkout)
Payment(PENDING), checkoutUrl отдан клиенту
   ↓  клиент вводит карту на странице Freedom Pay — номер карты никогда не попадает на сервер ZAIRO
Freedom Pay Result-notify webhook (подписанный pg_sig)
   ↓
Payment(SUCCEEDED) + Booking(CONFIRMED) — одна транзакция
```

**Бронь без предоплаты.** Если по правилам бизнеса онлайн ничего платить не нужно
(политика «без предоплаты» — она по умолчанию у нового бизнеса — или бесплатная
услуга, то есть депозит равен 0), бронь **подтверждается сразу при создании**
(`BookingService.createBooking`, событие `BookingConfirmedEvent`), платёж не
создаётся, а клиент платит на месте. Раньше такая бронь оставалась в
`PENDING_PAYMENT`, а `POST /bookings/{id}/payments` списывал с клиента **полную
цену** онлайн. Следствие: комиссия платформы (`PaymentAllocation`) и выплата
бизнесу (`BusinessPayout`) возникают только с онлайн-платежей — деньги,
принятые бизнесом на месте, в них не попадают.

**В мобильном приложении** (`BookingPaymentScreen`): сразу после создания брони
приложение вызывает `POST /bookings/{id}/payments`. Если платёж `SUCCEEDED`
(мок) — показывается подтверждение, как раньше. Если `PENDING` (Freedom Pay) —
открывается экран «Ждём оплату»: страница оплаты (`checkoutUrl`, только https)
открывается в браузере телефона, а экран опрашивает сервер каждые ~3 с и сразу
при возвращении в приложение, пока бронь не станет `CONFIRMED` (подтверждает
только webhook, а не возврат на страницу успеха). `FAILED` — кнопка «Попробовать
снова»; бронь, снятая сервером по таймауту, — состояние «Оплата не подтверждена».
Бронь, ожидающая оплаты, видна во вкладке «Предстоящие» с кнопкой «Оплатить»
(продолжение оплаты) и кнопкой отмены. Повторное `POST` при уже открытой оплате
возвращает ту же оплату (тот же `checkoutUrl`), а не создаёт вторую.

Сумма всегда берётся из `Booking.totalPrice` (которая в свою очередь взята
из `ServiceOffering.price` при создании брони) — клиентское приложение
никогда не передаёт сумму, которую backend бы "поверил на слово". См.
`BookingService.createBooking` и `PaymentsService.createPayment`.

## 2. Где находится оплата до settlement

**В собственном merchant-счёте ZAIRO во Freedom Pay.** Это подтверждённый
факт (ADR-0006/ADR-0007) — не эскроу, не отдельный счёт для каждого
бизнеса. Freedom Pay выступает "System Operator", ZAIRO — единственный
"Merchant" (`pg_merchant_id`) для всех транзакций платформы. Один и тот же
секрет (`FREEDOMPAY_SECRET_KEY`) подписывает все запросы и проверяет все
webhook'и — см. `FreedomPayProperties`.

**Это важное ограничение, а не деталь реализации**: до того момента, как
платформенный админ вручную переведёт деньги бизнесу, 100% суммы находится
под контролем ZAIRO. Подробнее — раздел "Known Limitations" в ADR-0007.

## 3. Как ZAIRO получает commission

В момент, когда `Payment` переходит в `SUCCEEDED` (синхронно для mock-
провайдера, через webhook — для Freedom Pay), `PaymentAllocationService`
считает разбивку через `CommissionCalculator`:

```
sum = Booking.totalPrice (например 15 000 KZT)
platformFee = round(sum × ставка)                        // ставка по умолчанию 0%; пример при 10% → 1 500 KZT
businessAmount = sum − platformFee                       // 13 500 KZT, НЕ отдельное округление
```

Результат сохраняется один раз в `PaymentAllocation` (таблица
`payment_allocation`, PK = `payment_id`) и больше не пересчитывается — даже
если ставка в настройках изменится позже. Инвариант
`businessAmount + platformFee == sum` проверяется в конструкторе
`PaymentAllocation` — расхождение — это баг, а не значение для сохранения
(fail-fast).

ZAIRO не "получает" комиссию отдельным переводом — комиссия — это просто
то, что остаётся в merchant-счёте ZAIRO после того, как `businessAmount`
будет выплачен бизнесу.

## 4. Как Business получает деньги

**Только после того, как услуга оказана** — `BusinessPayout` создаётся не
в момент оплаты, а в момент `Booking.COMPLETED`:

```
Владелец бизнеса нажимает "Завершить" → BookingService.completeBooking
   ↓  BookingCompletedEvent (уже существовал, слушателя не было до ADR-0007)
BookingCompletedPayoutListener (AFTER_COMMIT)
   ↓
BusinessPayout(PAYABLE), amount = PaymentAllocation.businessAmount
   ↓  платформенный админ переводит деньги вручную (банковский перевод) — Freedom Pay
   ↓  payout API с подтверждёнными полями для инициации выплаты не найден, см. ADR-0007
POST /api/v1/platform/payouts/{id}/mark-paid { providerReference: "..." }
   ↓
BusinessPayout(PAID) — терминальный статус
```

Бизнес видит свои выплаты через `GET /api/v1/providers/{providerId}/payouts`
(только владелец этого provider'а) — сумму, статус, когда оплачено.
Бизнес **не может** сам отметить свою выплату оплаченной — это
исключительно PLATFORM_ADMIN действие (`BusinessPayoutAdminController`).

Бронь, которая отменена/возвращена до `COMPLETED`, никогда не получает
`BusinessPayout` — платить за неоказанную услугу нечего.

## 5. Как происходит refund

Не изменилось относительно ADR-0006, с одним новым ограничением:

- До того, как `BusinessPayout` дошёл до `PROCESSING`/`PAID` — refund
  работает как и раньше: `POST /api/v1/payments/{id}/refund`
  (PLATFORM_ADMIN-only), `Payment` → `REFUNDED`.
- **После** того, как выплата бизнесу `PROCESSING`/`PAID` — refund
  заблокирован (`409 Conflict`) — деньги уже уходят/ушли бизнесу, а
  подтверждённого API для реверса выплаты нет (см. ADR-0007, Open
  Questions). Это требует ручной finance-реконсиляции, не автоматического
  refund'а.

Частичный refund не реализован — Freedom Pay поддерживает `pg_refund_amount`
меньше полной суммы (см. `FreedomPayProvider.refund`), но у Factory сегодня
нет продуктового сценария, который бы использовал частичную сумму; полный
refund — единственный путь.

## 6. Что происходит при cancellation

Как и раньше (ADR-0006) — `BookingCancelledPaymentListener` реагирует на
`BookingCancelledEvent` и рефандит `SUCCEEDED`-платёж автоматически.
Поскольку `BusinessPayout` создаётся только при `COMPLETED`, отменённая
бронь никогда не доходит до состояния, где refund был бы блокирован
пунктом 5 — отмена и выплата бизнесу взаимно исключают друг друга по
конструкции жизненного цикла брони.

## 7. Что происходит при no-show

`BookingService.markNoShow` переводит бронь в `NO_SHOW`, не в `COMPLETED` —
`BusinessPayout` **не создаётся**. Продуктовое решение о том, должен ли
no-show давать бизнесу право на компенсацию — вне рамок этой задачи, не
реализовано (означало бы новый триггер для `BusinessPayout`, не только
`BookingCompletedEvent`).

## 8. Что происходит при отказе провайдера

Не изменилось (ADR-0006): сетевая ошибка/исключение при вызове Freedom Pay
переводит `Payment` в `FAILED` без исключения из транзакции — тот же
идемпотентный `paymentId` можно использовать повторно (retry reuses the
same row). Бронь остаётся `PENDING_PAYMENT` для повторной попытки, либо
истекает по таймауту (`BookingPaymentTimeoutJob`).

## 9. Как работает webhook

Не изменилось (ADR-0006) — `PaymentWebhookController` →
`FreedomPayWebhookVerifier` (проверка `pg_sig`) → `PaymentWebhookProcessor`
(дедупликация по терминальному статусу `Payment`, не по event id — у
Freedom Pay Result-notify нет отдельного id доставки). Единственное
дополнение этой задачи: успешный переход в `SUCCEEDED` теперь также
создаёт `PaymentAllocation` в той же транзакции (`PaymentAllocationService.ensureAllocation`).

## 10. Как работает reconciliation

`PaymentReconciliationService.reconcile(paymentId)` сравнивает
`Payment.status` в БД ZAIRO с тем, что реально отвечает провайдер
(`PaymentProvider.getPaymentStatus` — метод порта, который существовал в
ADR-0006, но не имел вызывающего кода до этой задачи). Никогда не
исправляет расхождение молча — только возвращает `MATCH`/`DISCREPANCY`
платформенному админу (`POST /api/v1/platform/payments/{id}/reconcile`).
Подробный контракт — [docs/PAYMENT_RECONCILIATION.md](PAYMENT_RECONCILIATION.md).

## 11. Что нужно настроить в Freedom Pay / в конфигурации ZAIRO

Все параметры — через переменные окружения (существующий механизм
конфигурации Spring `@ConfigurationProperties`), ни один секрет не
закоммичен:

```bash
PAYMENT_PROVIDER=freedompay
FREEDOMPAY_API_URL=<хост из мерчант-кабинета Freedom Pay>
FREEDOMPAY_MERCHANT_ID=<merchant id>
FREEDOMPAY_SECRET_KEY=<secret key>                     # НИКОГДА в git
FREEDOMPAY_RESULT_NOTIFY_SCRIPT_NAME=<script name из кабинета>  # см. ADR-0006 Open Questions #6
PAYMENT_SUCCESS_URL=https://<адрес API>/pay/return/success   # страница возврата, открывает приложение
PAYMENT_FAILURE_URL=https://<адрес API>/pay/return/failure
```

Комиссия **не** настраивается переменной окружения: её меняет
PLATFORM_ADMIN в консоли (Финансы → Комиссия) или через API
`/api/v1/platform/commission`. Ставка по умолчанию — **0%** (комиссии нет,
пока платформа не решит её ввести); для каждой категории каталога можно
задать собственную ставку, остальные категории следуют ставке по умолчанию.
Какая ставка применится к брони: бизнес → его тип → категория → её ставка,
иначе ставка по умолчанию. Изменение действует только для новых оплат —
уже созданные `PaymentAllocation` хранят ставку на момент оплаты. Каждое
изменение пишется в аудит-лог платформы.

### Возврат в приложение после оплаты

`PAYMENT_SUCCESS_URL` / `PAYMENT_FAILURE_URL` указывают на страницы самого API
(`PaymentReturnController`): они публичные, без авторизации, и открывают приложение
по ссылке `zairo://app/payment-result?status=success|failure&booking=<id>` (плюс кнопка
«Открыть приложение», потому что браузер может не пустить автоматический переход).
К адресу бэкенд сам добавляет `?booking=<id>` (`PaymentReturnUrls`). В приложении ссылка
открывает `PaymentResultScreen`, который читает бронь и платёж с сервера и ждёт подтверждения
webhook'а: **сама ссылка ничего не доказывает**. Если клиент вернулся не по ссылке (закрыл
страницу, ссылка не открылась), экран оплаты всё равно опрашивает сервер и реагирует на
возвращение в приложение. Схема `zairo://` зарегистрирована в Android-манифесте и iOS
`Info.plist`; https-ссылки приложений (App Links / Universal Links) потребуют подтверждённого
домена и пока не настроены.

## 12. Какие вопросы требуют подтверждения от Freedom Pay

Полный список — ADR-0007's "Open Questions" (наследует все нерешённые
вопросы ADR-0006 плюс новые про выплаты). Кратко, что блокирует что:

- **Настоящий marketplace/split продукт Freedom Pay** (без того, чтобы
  ZAIRO держал деньги бизнеса на своём счёте до выплаты) — не подтверждён
  публичной документацией, требует прямого контакта с бизнес-командой
  Freedom Pay. Блокирует переход от "ручная выплата" к "настоящий split".
- **Поля запроса инициации G2G-выплаты** (`g2g/payout`) — найдены только
  поля ответа `payout_status`, не поля самого запроса на выплату.
  Блокирует автоматизацию `BusinessPayoutAdminController.markPaid` через
  реальный Freedom Pay API вместо банковского перевода вручную.
- **KYC/онбординг каждого бизнеса** для получения выплат — не
  подтверждён.
- Всё, что уже было открытым вопросом в ADR-0006 (recurring-списание,
  `/revoke` vs `/g2g/refund`, фискальные позиции чека, подпись ответа на
  webhook) — не переоценивается здесь, остаётся как есть.

Ничего из этого не блокирует то, что уже реализовано и протестировано:
расчёт комиссии, выплата после завершения услуги, защита refund'а после
выплаты, и reconciliation — работают на подтверждённой части Freedom
Pay API плюс собственной бухгалтерии ZAIRO.
