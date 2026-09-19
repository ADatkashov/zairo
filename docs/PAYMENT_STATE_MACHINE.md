# Payment / Settlement — конечные автоматы

Три раздельных статуса живут на трёх разных сущностях — сознательно не
собраны в одну переменную (`payment.status = EVERYTHING`), см. задачу, из
которой выросли ADR-0006/ADR-0007. Каждый — отдельный конечный автомат со
своим набором разрешённых переходов.

## 1. `PaymentStatus` (booking-платёж, ADR-0006 — не менялся этой задачей)

```
CREATED ──────► PENDING ──────► SUCCEEDED ──┬──► REFUNDED
   │                │                        │        ▲
   │                │                        │        │ (retry)
   ▼                ▼                        └──► REFUND_FAILED
 FAILED          FAILED
```

- `CREATED` — строка создана, `init_payment` ещё не подтверждён.
- `PENDING` — Freedom Pay принял запрос, есть `checkoutUrl`, ждём Result
  notify.
- `SUCCEEDED` — платёж подтверждён (webhook или синхронно у mock-провайдера).
- `FAILED` — терминально для *этой* попытки, но не для брони: тот же
  `Payment` можно перезарядить повторно (тот же `id` = idempotency key).
- `REFUNDED`/`REFUND_FAILED` — только из `SUCCEEDED`; `REFUND_FAILED`
  retriable (повторный `refundPayment` разрешён).
- `REFUND_PENDING` — определён для полноты (Freedom Pay `/revoke` может
  оказаться асинхронным), но не достижим сегодняшним кодом — см. ADR-0006.

**Запрещённые переходы** (не проверяются явным guard'ом на каждом пути, но
не достижимы по конструкции кода): `REFUNDED → SUCCEEDED`,
`REFUNDED → PENDING`, любой переход из `REFUNDED` вообще (терминален).

## 2. `BookingStatus` (не менялся этой задачей, см. ADR-0006)

```
PENDING_PAYMENT ──► CONFIRMED ──┬──► COMPLETED
        │                       ├──► CANCELLED (+ refund event)
        ▼                       └──► NO_SHOW
    CANCELLED
```

`Payment.SUCCEEDED` ≠ `Booking.COMPLETED` — подтверждение оплаты только
переводит бронь в `CONFIRMED`; `COMPLETED` — отдельное, ручное действие
владельца бизнеса (`BookingService.completeBooking`), никогда не
автоматическое.

## 3. `BusinessPayoutStatus` (новый, ADR-0007)

```
PAYABLE ──┬──► PROCESSING ──┬──► PAID  (терминально)
          │                 └──► FAILED ──┐
          └─────────────────► PAID        │
                    ▲                     │
                    └─────────────────────┘  (retry: FAILED → PROCESSING/PAID разрешён)
```

- `PAYABLE` — бронь `COMPLETED`, платёж `SUCCEEDED`, выплата ещё не начата.
  Создаётся **только** из `BookingCompletedEvent` — никогда при оплате.
- `PROCESSING` — админ начал перевод (опциональный промежуточный шаг —
  `mark-paid` можно вызвать и прямо из `PAYABLE`).
- `PAID` — терминально. Единственный способ выйти из `PAID` — не через
  этот конечный автомат вообще (см. ниже "Booking.COMPLETED ≠ payout
  успешен").
- `FAILED` — retriable, тот же принцип, что `Payment.REFUND_FAILED`:
  видимо для админа (`refundFailureReason`-эквивалент — `failureReason`),
  не тихая потеря.

Реализовано в `BusinessPayout.markProcessing/markPaid/markFailed` —
каждый метод бросает `PaymentConflictException` (409), если текущий
статус уже `PAID` (см. `requireNotTerminal`). `PAYABLE → PAID` и
`FAILED → PAID` — оба разрешены напрямую, без обязательного прохождения
через `PROCESSING`.

**Важное явное требование задачи, выполненное намеренно раздельно**:
`Booking.COMPLETED` **не** означает "выплата бизнесу успешна" — это два
независимых факта на двух независимых сущностях. `BusinessPayout` может
провисеть в `PAYABLE` сколько угодно (до ручного действия админа) без
какого-либо обратного влияния на уже завершённую бронь.

## Как эти три автомата взаимодействуют

```
Payment: CREATED → PENDING → SUCCEEDED ────────────────────────► REFUNDED
                                  │                                   ▲
                                  ▼                                   │ (блокируется, если ниже PROCESSING/PAID)
Booking: PENDING_PAYMENT → CONFIRMED → COMPLETED                      │
                                            │                         │
                                            ▼                         │
BusinessPayout:                        PAYABLE → PROCESSING → PAID ───┘
                                                        │
                                                        ▼
                                                     FAILED (retriable)
```

Единственная явная связь между `PaymentStatus` и `BusinessPayoutStatus`:
`PaymentsService.refundPayment` читает `BusinessPayout` для этого платежа
(если есть) и отказывает в refund'е, если его статус `PROCESSING`/`PAID` —
см. ADR-0007's "Refund/Payout Interaction". Это единственное место, где
одна сущность "смотрит" на статус другой; ни `Payment`, ни `Booking`, ни
`BusinessPayout` не получают новых полей друг от друга сверх этого одного
guard'а.
