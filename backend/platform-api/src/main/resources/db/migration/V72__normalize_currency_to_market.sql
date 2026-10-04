-- Services were created with a hardcoded 'USD' by the business app, while the
-- platform's only market is Kazakhstan (KZT). Align existing rows with the
-- currency of their city (cities carry their country's currency), and — for
-- services that never got a city — with the single ACTIVE country's currency.
-- Skipped when more than one currency is active: then there is no safe default.
update service s
set currency = c.currency
from city c
where s.city_code = c.code
  and s.currency <> c.currency;

update service
set currency = (select min(currency) from country where status = 'ACTIVE')
where city_code is null
  and (select count(distinct currency) from country where status = 'ACTIVE') = 1
  and currency <> (select min(currency) from country where status = 'ACTIVE');

-- Bookings and payments carry a copy of the service currency (see V17).
update booking b
set currency = s.currency
from service s
where b.service_id = s.id
  and b.currency <> s.currency;

update payment p
set currency = b.currency
from booking b
where p.booking_id = b.id
  and p.currency <> b.currency;
