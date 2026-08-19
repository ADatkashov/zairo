# ERD — Core доменная модель (Phase 1)

Минимальный набор сущностей, общий для любого vertical. Ничего специфичного
для Beauty здесь нет — vertical-модули расширяют эти сущности (например,
`Service` в Beauty получит связанный `master_id`), а не переопределяют их.

```mermaid
erDiagram
    USER ||--o{ BOOKING : "делает"
    USER ||--o| PROVIDER : "может быть владельцем"
    PROVIDER ||--o{ SERVICE : "предлагает"
    PROVIDER ||--o{ AVAILABILITY_SLOT : "публикует"
    SERVICE ||--o{ BOOKING : "заказывается через"
    BOOKING ||--o| REVIEW : "может получить"
    BOOKING }o--|| AVAILABILITY_SLOT : "занимает"

    USER {
        uuid id PK
        string email
        string phone
        string display_name
        string role "customer | provider_owner | admin"
        timestamp created_at
    }

    PROVIDER {
        uuid id PK
        uuid owner_user_id FK
        string name
        string vertical "beauty | auto | ... (Core хранит как opaque строку)"
        string status "pending | active | suspended"
        timestamp created_at
    }

    SERVICE {
        uuid id PK
        uuid provider_id FK
        string title
        int duration_minutes
        decimal price
        string currency
        boolean is_active
    }

    AVAILABILITY_SLOT {
        uuid id PK
        uuid provider_id FK
        timestamp starts_at
        timestamp ends_at
        string status "open | held | booked"
    }

    BOOKING {
        uuid id PK
        uuid user_id FK
        uuid service_id FK
        uuid availability_slot_id FK
        string status "pending | confirmed | cancelled | completed"
        decimal total_price
        timestamp created_at
    }

    REVIEW {
        uuid id PK
        uuid booking_id FK
        int rating "1..5"
        string comment
        timestamp created_at
    }
```

## Границы модулей (для владения таблицами)

| Bounded context (Gradle-модуль) | Владеет таблицами |
|---|---|
| `users` | `USER` |
| `providers` | `PROVIDER` |
| `services` | `SERVICE` |
| `booking` | `AVAILABILITY_SLOT`, `BOOKING` |
| `reviews` | `REVIEW` |
| `auth` | учётные данные/токены — отдельно от `USER` (см. ADR ниже) |
| `payments`, `notifications`, `search` | пока без своих таблиц — появятся в Phase 2 |

## Принципиально важное для Core/Vertical границы

- `PROVIDER.vertical` — просто строка, Core её не парсит и не ветвится по
  ней (`if vertical == 'beauty'` в Core-коде запрещено принципом из Factory
  Blueprint).
- Vertical-специфичные атрибуты (например, «мастер» и «портфолио» для
  Beauty) не добавляются как колонки в `SERVICE`/`PROVIDER` — они будут жить
  в отдельных таблицах vertical-модуля, связанных 1:1 по `provider_id`/
  `service_id`. Это первая практическая проверка принципа "Core не знает
  про vertical" на реальной схеме БД.
- `AVAILABILITY_SLOT` смоделирован общим (диапазон времени + статус), а не
  как что-то Beauty-специфичное (например, "слот мастера") — общая
  concept, которую заимствует любой vertical с бронированием по времени.

## Не смоделировано намеренно (см. Factory Blueprint §19)

- Multi-tenant изоляция БД (schema-per-tenant, RLS) — не нужна, пока нет
  второго независимого заказчика/tenant.
- История/аудит (event sourcing, outbox) — достаточно `created_at` полей и
  доменных событий в процессе (см. ADR-0002).
- Отмена/возврат оплаты как отдельная сущность — появится вместе с
  `payments`-модулем в Phase 2.
