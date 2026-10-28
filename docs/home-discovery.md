# Home discovery: popular services and personal recommendations

What the customer app's Home shows besides search and categories, where each list comes from, and what happens when
the data is not there. Code: `backend/search` (module `search`) and `apps/user_app/lib/features/discovery`.

The API reference is the OpenAPI spec (`/v3/api-docs`, every operation is documented and checked by `OpenApiTests`);
regenerate the local Postman collection from it with `scripts/sync-postman.sh`. The collection is not committed
(`docs/local/` is git-ignored) because it drifts from the real API.

## Endpoints

| Endpoint | Auth | Returns |
|---|---|---|
| `GET /api/v1/search/popular-services?city=&limit=` | public | The services customers booked most lately: `title`, `bookings`, `providerCount`, `minPrice`, `currency`. `limit` 1-20, default 8. |
| `GET /api/v1/users/{userId}/recommendations?city=&limit=` | the user themself (403 otherwise) | Businesses to show this customer: `providerId`, `vertical`, in display order. `limit` 1-30, default 10. |
| `GET /api/v1/users/{userId}/book-again` | the user themself | Existing. Services they completed, to repeat. |

## Popular services

- **Signal**: bookings made in the last 90 days with status `CONFIRMED` or `COMPLETED` (an unpaid, cancelled or no-show
  booking is not "booked"), optionally only those of one city (`booking.city_code`). One grouped query
  (`BookingRepository.countBookingsPerService`), not one count per service.
- **Eligibility**: only active offerings of `ACTIVE` businesses, so nothing a customer cannot book is advertised.
- **Grouping**: offerings with the same title (ignoring case and spacing) and currency are one service across
  businesses; `bookings` is summed, `providerCount` counts distinct businesses, `minPrice` is the lowest.
- **Order**: most bookings, then more businesses, then title (stable between calls). The most booked offering names the
  service.
- **Empty** on a platform with no bookings yet. The app then lists the services the loaded search results offer
  (most businesses first), so Home is never blank on a young platform.

## Recommendations

- **Learned from the customer's own kept bookings** (`CONFIRMED`/`COMPLETED`): which categories (`vertical`) they book
  in and how much.
- **Candidates**: `ACTIVE` businesses of those categories, in the customer's city plus those that have not set a city
  (same rule as search), excluding every business they have already been to (that is what "book again" is for).
- **Score**: `2 * (share of their bookings in the category) + (Bayesian rating / 5)`. So the category they use most
  leads, and inside a category the better-rated business wins; an unrated business counts as rating 0. Ties by id.
- **Returns ids only**: the app already holds the business details from search and orders them. A recommended business
  that is not in the loaded search page (50 per city) is skipped.
- **Empty** with no booking history. The app then shows the generic best-rated list under the plain title; it only
  says "Picked for you" when the list really came from their history.

## In the app

Both lists are best-effort extras of Home: an error, an older backend without the endpoint, no city or no history is
treated as "nothing yet" and Home keeps the previous behaviour; neither can block the screen. Tapping a popular
service opens Search for that title.

## Deliberate limits

- No machine learning and no collaborative signal ("people like you"): the rules above are transparent and cheap.
  Revisit when there is enough booking volume to measure that something better actually converts more.
- No caching: both are read-only computations over existing tables, like `book-again`. Add caching only when it is
  measurably slow.
- Popularity counts bookings, not revenue or reviews.

## Tests

- Ranking rules (pure): `PopularServicesRankerTest`, `RecommendationsRankerTest`.
- End to end on a real Postgres: `PopularServicesApiTests`, `RecommendationsApiTests`; `EndpointAuthPolicyTests` lists
  `GET /api/v1/search/popular-services` as intentionally public.
- App: `discovery_api_test`, `popular_services_test`, `home_screen_test`.
