# Защита HTTP API

## Как устроено сейчас
1. **Spring Security** (`platform-api`, пакет `security`): stateless, без CSRF/сессий/form-login/basic,
   security-заголовки (`nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`), CORS по-прежнему
   в `WebConfig`. 401/403 рисуются обычным обработчиком ошибок — тело то же `ApiError`.
   Пользователя по умолчанию нет (`UserDetailsService` пустой): вход идёт через `AuthService` / `PlatformAdminService`.
2. **Токены.** `JwtAuthFilter` (клиенты и бизнес) и `PlatformAuthFilter` (консоль платформы, свой секрет)
   проверяют JWT и работают *до* цепочки Spring Security; `TokenAuthenticationFilter` превращает валидный токен
   в аутентификацию (`ROLE_<роль>` или `PLATFORM_<роль>` — два семейства токенов не подменяют друг друга).
   Атрибуты запроса (`CurrentUser`, `PlatformCurrentAdmin`) остаются для контроллеров.
3. **«Закрыто по умолчанию».** `EndpointAuthorizationManager`: эндпоинт с `@SecurityRequirement` без
   валидного токена получает 401 — до валидации тела и до обращения к БД. Кто именно вызывает и что ему
   можно (владелец, роль) пока проверяют контроллеры (`ProviderOwnership`, `requirePlatformAdmin`, …).
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

## Дальше (этап 2 Spring Security)
Роли и владение переносятся из контроллеров в декларативные правила (`@PreAuthorize` по `ROLE_*` /
`PLATFORM_*`, владение бизнесом — через `PermissionEvaluator` поверх `ProviderOwnership`), модуль за
модулем, с тестами на каждый перенос. JWT-фильтры можно будет перенести внутрь цепочки как
`oauth2ResourceServer` или оставить как есть — это отдельное решение.
