# Защита HTTP API

## Как устроено сейчас
1. **Spring Security** (`platform-api`, пакет `security`): stateless, без CSRF/сессий/form-login/basic,
   security-заголовки (`nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`), CORS по-прежнему
   в `WebConfig`. 401/403 рисуются обычным обработчиком ошибок — тело то же `ApiError`.
   Пользователя по умолчанию нет (`UserDetailsService` пустой): вход идёт через `AuthService` / `PlatformAdminService`.
2. **Токены.** `JwtAuthFilter` (клиенты и бизнес) и `PlatformAuthFilter` (консоль платформы, свой секрет)
   проверяют JWT и работают *до* цепочки Spring Security; `TokenAuthenticationFilter` превращает валидный токен
   в аутентификацию (`ROLE_<роль>` для клиентов/бизнеса, `PLATFORM_ADMIN` / `PLATFORM_MODERATOR` / `PLATFORM_SUPPORT` для консоли — два семейства токенов не подменяют друг друга).
   Атрибуты запроса (`CurrentUser`, `PlatformCurrentAdmin`) остаются для контроллеров.
3. **«Закрыто по умолчанию».** `EndpointAuthorizationManager`: эндпоинт с `@SecurityRequirement` без
   валидного токена получает 401 — до валидации тела и до обращения к БД. Токен «не того семейства»
   (клиентский на платформенном эндпоинте) считается отсутствием токена: 401, а не 403.
3a. **Роли и владение — аннотациями** (method security, `@EnableMethodSecurity`):
   `@PlatformAdminOnly`, `@PlatformModerationCapable`, `@AnyPlatformRole` (платформенные роли) и
   `@OwnsProvider` (вызывающий — владелец бизнеса из параметра `providerId`; ответы те же: 401/404/403).
   Для сущностей: `@OwnsService` (услуга → её бизнес) и `@OwnsSlot` (слот → его бизнес); несуществующий id
   проходит проверку и получает собственный ответ метода (404, а у идемпотентного deactivate — 204).
   Если SpEL не вычисляется (переименовали параметр) — ответ 500, то есть закрыто, а не открыто;
   структурные тесты в `OwnsProviderApiTests` ловят это заранее.
   **Намеренно императивными остаются ~58 проверок в сервисном слое** (`*DirectoryService`, `BookingService`,
   `ReviewService`, `MessagingService`, workforce…): там вызывающий приходит параметром, часть проверок условная
   («клиент ИЛИ владелец», «если слот привязан к мастеру…»), и аннотация на ручке изменила бы логику, а не
   только способ записи. Они покрыты API-тестами; переносить их стоит вместе с заменой `requestingUserId`
   на принципала (`@AuthenticationPrincipal`), а не раньше.
4. **Явный список публичных эндпоинтов.** `EndpointAuthPolicyTests` падает, если у эндпоинта нет
   `@SecurityRequirement` и его нет в `PUBLIC`. Тот же тест проверяет, что каждый защищённый эндпоинт
   отвечает анонимному запросу 401.
5. **Лимиты.** `AuthRateLimitFilter` (по IP и, где есть, по email): вход, регистрация, восстановление
   пароля, обновление токена, вход в консоль платформы. 429 + `Retry-After`. Дополняет блокировку
   аккаунта по email при входе (`LoginAttemptLimiter`) и лимиты OTP. Счётчики в памяти
   (один инстанс, ADR-0001); при нескольких инстансах нужен общий стор.
   Выключатель: `app.rate-limit.enabled` (в интеграционных тестах выключен).

## Как добавить эндпоинт
Защищённый — `@SecurityRequirement(name = "bearerAuth")` + проверка владения в контроллере.
Публичный — добавить строку в `EndpointAuthPolicyTests.PUBLIC` и объяснить в ревью, почему.

## Дальше
Перенос JWT-фильтров внутрь цепочки Spring Security (`oauth2ResourceServer` или свой `AuthenticationProvider`) и
отказ от атрибутов запроса: контроллеры берут принципала через `@AuthenticationPrincipal`, сервисы перестают
получать `requestingUserId` параметром — после этого оставшиеся проверки владения в сервисах становятся
декларативными без смены логики.
