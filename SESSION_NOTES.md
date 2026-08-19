# Заметки по восстановлению проекта (2026-08-19)

## Что было не так
В корне репозитория оказался вложен отдельный, полноценный нативный Android-проект
(`app/`, `build.gradle.kts`, `settings.gradle.kts`, `gradlew` и т.д. прямо в корне) —
похоже, Android Studio когда-то была открыта не на той папке. Это ломало и git-историю,
и Gradle-сборку, и конфигурацию IDE.

## Что исправлено (закоммичено, коммит `fc2a561`, запушено в `origin/master`)
- Удалён весь дублирующий Android-проект в корне (`app/`, корневые `build.gradle*`,
  `settings.gradle*`, `gradle/`, `gradlew(.bat)`, `local.properties`).
- `.gitignore` дополнен: `android/build/`, `android/app/build/`, `.gradle/`,
  `.gradle_home/`, `local.properties`.
- `android/build.gradle.kts` — восстановлено стандартное перенаправление build-директории
  Flutter (`rootProject.layout.buildDirectory...`), без него Flutter CLI не находил
  собранный APK.
- `android/app/build.gradle.kts` — `compileSdk` поднят до `37` (требование
  `flutter_secure_storage`), иначе падал `checkDebugAarMetadata`.
- `flutter analyze` — чисто, `flutter test` — проходит, `flutter build apk --debug` —
  собирается.

## Локальные (не в git) правки IDE-конфига
`.idea/` в git не попадает, поэтому эти правки нужно помнить — при переклонировании
репозитория на новой машине эта же проблема может повториться:
- `.idea/gradle.xml`: `externalProjectPath` был `$PROJECT_DIR$` (корень репо) —
  переставлен на `$PROJECT_DIR$/android` (реальный Gradle-проект).
- `.idea/misc.xml`: убран `<component name="ProjectType"><option name="id" value="Android" /></component>` —
  он заставлял Android Studio считать весь проект чистым Android-проектом и скрывал
  Flutter-конфигурацию запуска (`main.dart`).

## Проблема с push
Локальный git не мог проверить SSL-сертификат GitHub из-за перехвата HTTPS антивирусом
AVG. Решение (уже применено пользователем):
```
git config --global http.sslBackend schannel
```

## Текущий статус запуска в Android Studio
После правки `.idea/misc.xml` нужно:
1. `File → Invalidate Caches / Restart → Invalidate and Restart`.
2. Дождаться индексации и Gradle sync.
3. В выпадающем списке конфигураций выбрать **`main.dart`** (зелёная иконка Flutter),
   а не `zairo_android`.
4. Выбрать устройство (эмулятор `sdk gphone16k x86 64` или Windows/Chrome) и нажать Run.

**Подтверждено пользователем 2026-08-19 04:05**: конфигурация `main.dart` появилась,
приложение успешно запущено на эмуляторе Pixel 9 Pro (`com.zairo/.MainActivity`).
Проект полностью рабочий.

## На заметку
`android/app/google-services.json` присутствует, но в `pubspec.yaml` нет Firebase-зависимостей
и плагин `google-services` нигде не подключён — файл сейчас ни на что не влияет.
Если Firebase не планируется — можно удалить.

---

# Factory — платформа для marketplace-приложений (с 2026-08-19)

## Идея
Проект разворачивается в платформу **Factory** (рабочее кодовое имя, не финальный
бренд) — набор переиспользуемых Flutter + Spring Boot модулей для быстрой сборки
сервисных marketplace-приложений в разных отраслях. Первый vertical — Beauty.

Полный product discovery / architecture plan — опубликованный артефакт
**Factory Blueprint** (20 разделов: концепция, монорепо, Core/Marketplace/Vertical,
MVP scope, backend/db/flutter-архитектура, roadmap Phase 0–9, чего не делать сейчас
и т.д.). Ссылка на артефакт есть в истории чата этой сессии — если потерялась,
можно пересоздать по этим заметкам или спросить пользователя.

Решение пользователя: репозиторий `zairo` **эволюционирует** в корень монорепо
`app-factory`, отдельный репозиторий не создаётся.

## Phase 1, шаг 1 — Flutter-скелет монорепо (сделано)
- `apps/user_app` — бывший `zairo`, перенесён через `git mv` (история сохранена).
- `packages/core_network` — Dio-клиент + `Failure`/`NetworkFailure`/`ServerFailure`.
  Важно: `baseUrl` **не зашит** в пакет — `networkConfigProvider` должен быть
  переопределён приложением (`apps/user_app/lib/core/constants/environment.dart` →
  `main.dart` через `ProviderScope(overrides: ...)`). Это реализация принципа
  "Core не знает про App/Vertical".
- `packages/core_storage` — `SecureStorageService` + `CacheFailure`.
- Убрано дублирование `AppConstants` vs `AppConfig` (было два конкурирующих
  недописанных конфига) — оставлен один `AppConfig` (имя, тема) в приложении.
- `melos.yaml` в корне — управление workspace, но **не проверен фактическим
  запуском** (`melos bootstrap`/`melos run`) — пакеты и так резолвятся через
  обычные `path:`-зависимости в pubspec.yaml, melos опционален.
- Проверено: `flutter pub get`/`analyze`/`test`/`build apk --debug` — всё проходит
  из нового расположения `apps/user_app/`.
- Корневой `.gitignore` переписан под монорепо-уровень (build/, .dart_tool/,
  .gradle/ с `**/`-паттернами), Flutter-специфичный `.gitignore` уехал в
  `apps/user_app/.gitignore`.
- `.idea/` был снова удалён (стал невалиден после переноса) — после этого шага
  открывать в IDE нужно `apps/user_app` напрямую как отдельный проект, пока нет
  multi-root workspace конфигурации под Melos.

## Phase 1, шаг 2 — backend-скелет (сделано)
- `backend/` — Spring Boot **4.1.0** (актуальная стабильная линия на 2026-08-19,
  проверено через Maven-метадату plugins.gradle.org, не через веб-поиск — веб-поиск
  дал версию, которую пришлось перепроверять), Gradle multi-module, Java 21 toolchain.
- 9 пустых bounded-context модулей: `auth`, `users`, `providers`, `services`,
  `booking`, `payments`, `reviews`, `notifications`, `search` — каждый только с
  `package-info.java`, описывающим границу (без бизнес-логики, по правилу
  "маленькие законченные шаги").
- `platform-api` — единственный запускаемый модуль, собирает все остальные в один
  процесс (modular monolith). Реальный Spring Boot app с actuator health-check.
- Gradle wrapper переиспользован из `apps/user_app/android` (тот же Gradle 9.3.1,
  уже был в локальном кэше) — новый wrapper не создавался.
- `infrastructure/docker-compose.yml` — Postgres 17, Redis 7, MinIO (S3-совместимое
  хранилище). Ещё ни с чем не подключено (появится в Phase 2 с первыми сущностями).

### Проблема: AVG блокирует Gradle/JVM (не только git)
Тот же перехват HTTPS антивирусом AVG, что ломал `git push` (см. выше), ломает и
Gradle — JVM (JDK) использует **свой** truststore (`cacerts`), отдельный от
Windows-хранилища и от git's OpenSSL-бандла. Симптом: `Plugin ... was not found`
при резолвинге `org.springframework.boot` (или любого другого) плагина, без явной
SSL-ошибки в логе.

**Не трогал** системный `cacerts` в `C:\Program Files\Android\Android Studio\jbr\lib\security\cacerts`
(нужны права администратора, затронуло бы вообще все Java-приложения на машине).

**Решение (сделано, машинно-локальное, не в git):**
1. Скопирован системный `cacerts` → `C:\Users\Acer\.gradle\factory-truststore.jks`.
2. Настоящий корневой сертификат AVG (`CN=AVG Web/Mail Shield Root`, самоподписанный)
   экспортирован из Windows-хранилища (`Cert:\CurrentUser\Root`) через PowerShell —
   **не** из TLS-хендшейка (это была первая неудачная попытка: `openssl s_client`
   отдаёт только сгенерированный AVG leaf-сертификат для конкретного хоста, не
   сам root — leaf решил бы проблему только для одного домена).
3. Импортирован в копию truststore через `keytool -importcert`.
4. `C:\Users\Acer\.gradle\gradle.properties` (пользовательский, НЕ в проекте, НЕ в
   git — чтобы не навязывать этот machine-specific workaround другим разработчикам
   или CI):
   ```
   org.gradle.jvmargs=-Djavax.net.ssl.trustStore=C:/Users/Acer/.gradle/factory-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit
   ```
   Пароль truststore — стандартный `changeit` (не менялся при копировании).

Если на новой машине/у другого разработчика возникнет та же ошибка резолвинга
Gradle-плагинов без явной SSL-трассировки — с высокой вероятностью это тот же
класс проблемы (антивирус с HTTPS-сканированием), и чинится тем же способом на
их машине (не нужно чинить наш репозиторий).

### Проверено
- `cd backend && ./gradlew build` → BUILD SUCCESSFUL, все модули + `platform-api:test`
  (полный Spring-контекст со всеми bounded context модулями поднимается).
- `./gradlew :platform-api:bootRun` → реально стартовал, `curl localhost:8080/actuator/health`
  → `{"status":"UP"}`. Процесс остановлен после проверки.
- Build-каталоги (`backend/*/build/`, `.gradle/`) корректно игнорируются.

## Phase 1, шаг 3 — ERD + ADR (сделано)
- `docs/erd/core-domain.md` — ERD (Mermaid) для Core доменной модели:
  `USER`, `PROVIDER`, `SERVICE`, `AVAILABILITY_SLOT`, `BOOKING`, `REVIEW`.
  Таблица владения сущностями по Gradle-модулям. Явно прописано, что
  `PROVIDER.vertical` — непрозрачная строка для Core, а vertical-специфичные
  атрибуты (например, "мастер" для Beauty) не лезут колонками в Core-таблицы,
  а живут в отдельных таблицах vertical-модуля со связью 1:1.
- `docs/adr/0001-modular-monolith-not-microservices.md` — почему один
  деплой-юнит, а не сервисы по сети (нет команды, которой нужна раздельная
  деплой-каденция; границы модулей сохраняются на уровне кода).
- `docs/adr/0002-in-process-events-not-kafka.md` — почему
  `ApplicationEventPublisher`/`@TransactionalEventListener` вместо брокера
  сообщений (всё уже в одном процессе; Kafka — преждевременная
  инфраструктура без реального consumer'а в отдельном процессе).
- `docs/adr/0003-no-full-multitenant-db-isolation.md` — почему одна общая
  БД без schema-per-tenant/RLS (нет второго vertical/tenant ещё; изоляция
  сейчас на уровне кода — Core не трогает vertical-таблицы напрямую).
- `docs/adr/README.md` — обновлён, ссылки на все три ADR и на ERD.
- Каждый ADR содержит секцию "Когда пересматривать" — конкретный триггер
  для ревизии решения (второй vertical, отдельный процесс/сервис и т.д.),
  а не "пересмотрим когда-нибудь".

**Phase 1 полностью закрыт** (шаги 1, 2, 3 — все сделаны и задокументированы).

**Phase 1 закоммичено и запушено** (`dce253b`) — история переносов сохранена.

## Phase 2 — Marketplace core (начато 2026-08-19)

План разбит на шаги, подтверждён пользователем ("да начинай"): (1) users/
providers/services — сущности + миграции + CRUD на реальном Postgres,
(2) availability + booking, (3) reviews, (4) search, (5-6) Flutter-слой
поверх API.

### Шаг 1 — users/providers/services (сделано)
- Реальные JPA-сущности по `docs/erd/core-domain.md`: `User` (модуль
  `users`), `Provider` (модуль `providers`), `ServiceOffering` (модуль
  `services`, таблица `service` — класс назван не `Service`, чтобы не
  путаться со spring-стереотипом `@Service`).
- Flyway-миграции (`V1..V3`) лежат в `platform-api/src/main/resources/
  db/migration/` — осознанно централизованы в assembly-модуле, а не
  раскиданы по bounded-context модулям: один физический процесс/БД/
  Flyway-history, дробить пока незачем (см. рационале ADR-0001).
  Пересмотреть, если модуль когда-нибудь извлекается в отдельный сервис.
- Простые REST CRUD-контроллеры (create/list/getById) для каждого модуля,
  `POST /api/v1/providers/{id}/services` для дочерних сервисов.
- Тесты — против **реального** Postgres через Testcontainers
  (`@ServiceConnection`), не моки: `PlatformApiApplicationTests`
  (context+Flyway+JPA поднимаются) и `ProviderApiTests` (полный e2e-флоу
  users → providers → services по HTTP).
- Дополнительно вручную проверено: `docker compose up postgres` +
  `./gradlew :platform-api:bootRun` + curl по всей цепочке — реальные
  данные видны через `GET`.

### Неочевидные технические находки (Spring Boot 4.1 модуляризация)
Spring Boot 4.1 сильно раздробил монолитный `spring-boot-autoconfigure` на
множество мелких модулей — несколько привычных вещей переехали:
- `TestRestTemplate`: было `org.springframework.boot.test.web.client` →
  стало отдельный модуль `spring-boot-resttestclient`, пакет
  `org.springframework.boot.resttestclient`. Требует явную
  `@AutoConfigureTestRestTemplate` на тесте (раньше подключался неявно
  через `webEnvironment = RANDOM_PORT`), плюс `spring-boot-restclient`
  на classpath (иначе `ClassNotFoundException:
  org.springframework.boot.restclient.RestTemplateBuilder` при разрешении
  автоконфигурации).
- `EntityScan`: было `org.springframework.boot.autoconfigure.domain` →
  стало `org.springframework.boot.persistence.autoconfigure`.
- Flyway-автоконфигурация вынесена в отдельный старлет
  `spring-boot-starter-flyway` — просто `flyway-core` на classpath
  подключает библиotеку, но **не** `FlywayMigrationInitializer`; без
  старлета миграции молча не выполняются (Hibernate падает на
  `Schema validation: missing table`, без единого упоминания Flyway в
  логах — тратил время именно на это).
- Testcontainers 2.x переименовал модули с префиксом `testcontainers-`
  (`testcontainers-postgresql`, `testcontainers-junit-jupiter`) — старые
  1.x-координаты (`postgresql`, `junit-jupiter`) не существуют в 2.x.
- `io.spring.dependency-management` не разворачивает вложенный BOM-импорт
  (spring-boot-dependencies → testcontainers-bom) транзитивно — версии
  Testcontainers-артефактов пришлось пинить явно.
- Без флага компилятора `-parameters` (добавлен глобально в
  `backend/build.gradle.kts`) Spring MVC не резолвит `@PathVariable` по
  имени параметра — `IllegalArgumentException: Name for argument of type
  UUID not specified`. Актуально для каждого будущего контроллера.
- Каждый bounded-context модуль (`users`/`providers`/`services`), не
  подключающий сам плагин `org.springframework.boot`, не получает
  managed-версии зависимостей автоматически — пришлось явно
  импортировать `spring-boot-dependencies` BOM в `subprojects {}` в
  корневом `backend/build.gradle.kts`.
- `@SpringBootApplication(scanBasePackages = "com.zairo.factory")` сканит
  компоненты, но Spring Data JPA по умолчанию ищет репозитории только в
  пакете главного класса (`...platform`) — понадобились явные
  `@EntityScan`/`@EnableJpaRepositories(basePackages = "com.zairo.factory")`
  на `PlatformApiApplication`.

**Шаг 1 закоммичен и запушен** (`d4678af`).

### Шаг 2 — Availability + Booking (сделано)
- Модуль `booking` (владеет `AvailabilitySlot` + `Booking` по таблице
  владения из ERD): сущности, репозитории, REST CRUD.
- `AvailabilitySlot` использует `@Version` (JPA optimistic locking) на
  переходе `OPEN → BOOKED` — конкурентные запросы на один и тот же слот не
  могут оба выиграть; проигравший получает
  `OptimisticLockingFailureException`, который `BookingService` превращает
  в `409 Conflict` (`SlotNotAvailableException` + `@ResponseStatus`).
- `BookingService.createBooking` — одна транзакция: проверяет `slot.status
  == OPEN`, помечает слот `BOOKED`, создаёт `Booking` со статусом
  `CONFIRMED`, публикует `BookingConfirmedEvent` через
  `ApplicationEventPublisher` (см. ADR-0002).
- `BookingConfirmedEventListener` — `@TransactionalEventListener(phase =
  AFTER_COMMIT)`, пока просто логирует; это заглушка-доказательство, что
  механизм событий работает end-to-end. Реальный слушатель (например,
  отправка уведомления) появится, когда у `notifications`-модуля будет что
  реально отправлять — не тянул эту связь заранее.
- `userId`/`serviceId` в `Booking` — только UUID, без Java-зависимости
  модуля `booking` на `users`/`services` (граница bounded context
  соблюдена и на уровне кода, не только БД).
- `totalPrice` для бронирования передаётся клиентом в запросе (клиент уже
  получил цену через `GET /api/v1/services/{id}`), а не пересчитывается на
  сервере через прямой вызов `services`-модуля — осознанное упрощение,
  чтобы не создавать Java-зависимость `booking → services`. Пересмотреть,
  когда появится реальная бизнес-логика ценообразования (скидки, промо).
- Flyway `V4` (`availability_slot`, с колонкой `version`), `V5` (`booking`,
  уникальный индекс на `availability_slot_id` — защита от двойного букинга
  и на уровне БД, не только в приложении).
- Тесты на реальном Postgres (Testcontainers): `BookingApiTests` — полный
  флоу owner → provider → service → slot → booking, и явная проверка, что
  второе бронирование того же слота возвращает `409`.
- Вручную проверено: `docker compose up postgres` + `bootRun` + curl —
  первое бронирование `201/CONFIRMED`, повторное на тот же слот `409`,
  список броней пользователя показывает одну запись.
- `./gradlew build` — BUILD SUCCESSFUL с первой попытки (все находки про
  Spring Boot 4.1 модуляризацию из шага 1 уже были учтены).

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

## Следующий шаг — Phase 2, шаг 3 (не начат)
Reviews: отзыв на завершённое бронирование (`REVIEW` из ERD, `rating`
1..5, привязка к `booking_id`).
