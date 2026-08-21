-- booking.total_price never had its own currency column — it was
-- implicitly "whatever the platform's single configured currency is",
-- never actually stored (see the Money value-type migration in
-- SESSION_NOTES.md). Backfilled from each booking's own service, which
-- already has a real currency, rather than guessing a single default for
-- every existing row.
alter table booking add column currency varchar(3);

update booking b
set currency = s.currency
from service s
where b.service_id = s.id;

alter table booking alter column currency set not null;
