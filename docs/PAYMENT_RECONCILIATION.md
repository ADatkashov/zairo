# Payment Reconciliation

Как сверить состояние платежа в базе ZAIRO с тем, что реально знает
Freedom Pay — Phase 16 задачи, из которой выросли ADR-0006/ADR-0007.

## Зачем это отдельный механизм

Webhook — источник истины (ADR-0006), но webhook может не дойти: сетевая
проблема, неправильно настроенный Result URL в мерчант-кабинете (см.
ADR-0006's Open Questions #6), или просто задержка. Без reconciliation
такой платёж тихо застревает в `PENDING` навсегда, пока кто-то не заметит
вручную. `PaymentReconciliationService` даёт способ спросить у самого
Freedom Pay "а что у тебя записано по этому платежу" и явно увидеть
расхождение.

## Как это работает

```
POST /api/v1/platform/payments/{paymentId}/reconcile   (PLATFORM_ADMIN или PLATFORM_SUPPORT)
      ↓
PaymentReconciliationService.reconcile(paymentId)
      ↓
Payment.providerReference == null?
      │  да → MATCH (платёж никогда не достиг провайдера — нечего сравнивать)
      │  нет ↓
PaymentProvider.getPaymentStatus(paymentId, providerReference)
      ↓
Сравнение Payment.status (наша БД) vs providerResult.status (Freedom Pay)
      ↓
MATCH | DISCREPANCY
```

Ответ (`PaymentDtos.ReconciliationResponse`):

```json
{
  "outcome": "MATCH" | "DISCREPANCY",
  "localStatus": "SUCCEEDED",
  "providerStatus": "SUCCEEDED",
  "providerReference": "fp_..."
}
```

## Правила сравнения (`statusesAgree`)

| Наш `PaymentStatus` | Совпадает с провайдером, если провайдер отвечает |
|---|---|
| `SUCCEEDED` / `REFUNDED` / `REFUND_FAILED` / `REFUND_PENDING` | `SUCCEEDED` — провайдер списал средства; refund — отдельная концепция, `PaymentProvider.PaymentStatusResult` о ней ничего не знает |
| `FAILED` | `FAILED` |
| `PENDING` | **только** `PENDING` |
| `CREATED` | всегда `MATCH` (провайдер вообще не был вызван) |

**Ключевой нюанс**: `PENDING` намеренно **не** считается совпадением, если
провайдер уже отвечает `SUCCEEDED` или `FAILED` — это ровно тот случай
"webhook не пришёл", ради которого этот механизм существует. Более
снисходительное правило (например, "PENDING совпадает с чем угодно")
сделало бы reconciliation бесполезным именно в том случае, для которого
оно задумано.

## Что этот механизм **не** делает

- **Не исправляет расхождение автоматически.** `DISCREPANCY` — это сигнал
  человеку (платформенному админу), не триггер для скрытого обновления
  `Payment.status`. Прямое требование задачи: "нельзя молча исправлять
  финансовые данные".
- **Не является заменой webhook'а** — это fallback/аудит-инструмент
  (см. `PaymentProvider.getPaymentStatus`'s собственный doc comment:
  "a reconciliation fallback... not the primary confirmation path").
- **Не сверяет `BusinessPayout`** — сегодня сверяется только
  `Payment.status` против провайдера. Сверка "выплата бизнесу действительно
  дошла" зависит от банковского подтверждения перевода (вне Freedom Pay
  API — см. ADR-0007), не от чего-то, что этот сервис может спросить у
  провайдера.

## Что дальше (не реализовано, честно не замаскировано)

- **Не является периодической job'ой** — сегодня это on-demand вызов на
  один `paymentId`. Обнаружить "у нас застряло 5 платежей в PENDING больше
  суток" без явного запроса по каждому нельзя. Естественное развитие:
  `@Scheduled`-job (тот же паттерн, что `BookingPaymentTimeoutJob`/
  `SubscriptionRenewalJob`), которая находит все `PENDING`-платежи старше
  порога и вызывает `reconcile` для каждого, логируя/уведомляя о каждой
  `DISCREPANCY` — не реализовано в этой задаче, чтобы не добавлять
  недоказанную автоматизацию сверх того, что было явно нужно для
  MVP-выплат бизнесу.
- **Массовая сверка** (`GET /platform/payments/reconciliation` со списком
  расхождений сразу по многим платежам) — не реализована; сегодня — только
  по одному `paymentId` за вызов.
