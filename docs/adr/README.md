# Architecture Decision Records

Короткие записи о решениях, которые не очевидны из кода — что решили,
почему, какие альтернативы отклонили. Формат: `NNNN-short-title.md`.

- [0001 — Modular monolith, не микросервисы](0001-modular-monolith-not-microservices.md)
- [0002 — Внутрипроцессные события, не Kafka](0002-in-process-events-not-kafka.md)
- [0003 — Без полной multi-tenant изоляции БД](0003-no-full-multitenant-db-isolation.md)
- [0004 — Пересмотр 0003 после Auto vertical: решение не меняется](0004-revisit-multitenant-isolation-after-auto-vertical.md)
- [0005 — `@Scheduled`-джобы для биллинга подписок](0005-scheduled-jobs-for-subscription-billing.md)

ERD доменной модели, на которую опираются эти решения: `../erd/core-domain.md`.
