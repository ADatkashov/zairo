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

**Шаг 2 закоммичен и запушен** (`89b6b57`).

### Шаг 3 — Reviews (сделано)
- Обнаружил, что `package-info.java` модуля `reviews`, написанный ещё на
  Phase 1, уже фиксировал намерение: «a review requires a completed
  Booking — trust comes from verified visits, not free-form account
  creation». Это заставило расширить шаг: понадобился реальный переход
  бронирования в `COMPLETED`, которого раньше не было.
- `BookingService.completeBooking` (модуль `booking`) — `CONFIRMED →
  COMPLETED`, `409` через новый `InvalidBookingStateException`, если
  бронирование не в статусе `CONFIRMED`. Endpoint
  `POST /api/v1/bookings/{id}/complete`.
- `Review` (модуль `reviews`, таблица `review`): `bookingId` (unique),
  `rating` (1..5, проверяется и в приложении, и `CHECK`-constraint в БД),
  `comment`, `createdAt`.
- **Осознанное исключение из правила "только по ID"**: `reviews` имеет
  прямую Gradle-зависимость на `booking` (`implementation(project(":booking"))`)
  и читает `BookingRepository` напрямую, чтобы проверить
  `booking.status == COMPLETED` перед созданием отзыва. В отличие от связи
  `booking → users/services` (которой достаточно UUID для ассоциации),
  здесь нужна проверка реального инварианта доверия ("visit действительно
  состоялся") — это не просто ссылка на запись, а серверная валидация,
  которую нельзя доверить клиенту. Направление одностороннее (`reviews →
  booking`), циклов нет. Задокументировано прямо в `reviews/build.gradle.kts`.
- `ReviewService.createReview`: `400`, если `rating` вне 1..5; `404`, если
  бронирования не существует; `409`, если бронирование не `COMPLETED`;
  `409`, если отзыв на это бронирование уже есть (один отзыв на
  бронирование, как в ERD: `BOOKING ||--o| REVIEW`).
- Flyway `V6` (`review`, `CHECK (rating between 1 and 5)`, `unique` на
  `booking_id`).
- Тесты на реальном Postgres (Testcontainers): `ReviewApiTests` — полный
  флоу owner → provider → service → slot → booking → complete → review, с
  явными проверками всех веток (отзыв до завершения → 409, невалидный
  рейтинг → 400, дубль отзыва → 409).
- Вручную проверено: `docker compose up postgres` + `bootRun` + curl —
  все пять сценариев подтверждены кодами ответа именно как задумано.
- `./gradlew build` — BUILD SUCCESSFUL с первой попытки.

**Шаг 3 закоммичен и запушен** (`1d9b23a`).

### Шаг 4 — Search (сделано)
- `search`-модуль не владеет своими таблицами — чистая read-композиция
  поверх `providers`/`services`/`booking`. Обоснование в
  `search/build.gradle.kts`: для чтения (не для проверки инвариантов, как
  у `reviews → booking`) прямая Gradle-зависимость на другие модули —
  стандартный паттерн для search/query bounded context в модульном
  монолите.
- `GET /api/v1/search/providers?vertical=&q=` — фильтр по vertical (точное
  совпадение, как и было решено в ERD — vertical непрозрачен для Core) и
  по тексту (substring, регистронезависимо, по имени провайдера ИЛИ
  названию активного сервиса).
- Детерминированный рейтинг (см. `package-info.java` модуля `search`,
  написанный ещё на Phase 1: "rating, distance, price, availability"):
  реализованы **availability** (есть ли открытый слот) и **price**
  (минимальная цена активного сервиса) — сортировка: сначала есть
  доступность, затем по возрастанию цены.
  - **rating осознанно не реализован** в этом шаге: потребовал бы live
    JOIN на каждый поисковый запрос через
    services → bookings → reviews (3 модуля), это кандидат на
    материализованную read-модель, когда появится реальный трафик, а не
    поштучный join для MVP без данных. Отмечено прямо в
    `SearchService`-джавадоке.
  - **distance не реализован**: у `Provider` нет геоданных в ERD —
    осознанно отложено вместе с картами (Factory Blueprint §19).
- Добавлены недостающие query-методы в уже существующие репозитории
  (`ProviderRepository.findByVertical`,
  `ServiceOfferingRepository.findByProviderIdAndActiveTrue` /
  `findByTitleContainingIgnoreCaseAndActiveTrue`,
  `AvailabilitySlotRepository.existsByProviderIdAndStatus`) — расширение
  существующих модулей, а не новая таблица.
- **Находка про тестовую изоляцию**: `SearchApiTests` изначально падал —
  оказалось, Spring переиспользует один и тот же `ApplicationContext` (и
  соответственно один и тот же Testcontainers-Postgres с накопленными
  данными) между тестовыми классами с идентичным набором аннотаций
  (`ProviderApiTests`, `BookingApiTests`, `ReviewApiTests`, `SearchApiTests`
  — все объявляют `@SpringBootTest(RANDOM_PORT) @AutoConfigureTestRestTemplate
  @Import(TestcontainersConfiguration.class)`). Из-за этого данные из
  предыдущих тестовых классов "утекали" в `SearchApiTests`. Исправлено:
  тест генерирует случайный `vertical` на каждый прогон (никогда не
  сталкивается с чужими данными) и использует `containsSubsequence`
  вместо `containsExactly` там, где полный список принципиально может
  содержать чужие записи. **На будущее**: любой новый e2e-тест с таким же
  набором аннотаций будет делить БД с этими четырьмя — писать тесты с
  учётом этого (уникальные данные или сравнения, устойчивые к чужим
  записям), а не полагаться на "чистую" БД.
- Тесты на реальном Postgres (Testcontainers): `SearchApiTests` — фильтр
  по vertical, текстовый поиск, порядок сортировки.
- Вручную проверено: `docker compose up postgres` + `bootRun` + curl —
  фильтр по vertical, текстовый поиск и сортировка (доступность → цена)
  подтверждены на реальных данных (включая накопленные с прошлых шагов).
- `./gradlew build` — BUILD SUCCESSFUL (после исправления теста).

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

### Шаг 5-6 — Flutter data layer + UI: Discover-экран (сделано)
- Новая фича `apps/user_app/lib/features/discovery/`:
  - `data/models/` — `ProviderSearchResult`, `ServiceSummary`. **Без
    кодогенерации** (freezed/json_serializable сознательно не
    использованы для этого шага) — `freezed: ^4.0.0-dev.3` в pubspec.yaml
    выглядит нестабильно (dev-prerelease), а DTO простые и стабильные,
    ручной `fromJson` дешевле, чем разбираться с версией кодогена.
    freezed/json_serializable остаются в зависимостях для более сложной
    фичи в будущем, где кодоген действительно окупится.
  - `data/discovery_api.dart` — `DiscoveryApi` поверх `DioClient` из
    `core_network`, вызывает `GET /search/providers`. Класс не
    `final`/`sealed` специально — тесты подменяют его подклассом,
    переопределяющим `searchProviders`, вместо мокинга Dio.
  - `presentation/providers/discovery_providers.dart` — Riverpod
    `discoveryApiProvider` + `searchResultsProvider`
    (`FutureProvider.autoDispose.family`).
  - `presentation/screens/discovery_screen.dart` +
    `presentation/widgets/provider_card.dart` — поиск по тексту,
    список карточек (имя, vertical, "From \$price", чипы сервисов,
    бейдж "Available" при открытом слоте), состояния loading/error/empty,
    pull-to-refresh.
  - Экран подключён на таб **Home** в `app_router.dart` (заменил собой
    старый шаблонный `HomeScreen` — тот был мёртвым boilerplate-текстом
    про "ZAIRO... automation", ничего не терял; файл/папка `features/home`
    удалены).
  - `environment.dart`: `baseUrl` изменён с плейсхолдера
    `https://api.zairo.com/v1` (несуществующий домен, да ещё и без `/api`
    в пути!) на `http://localhost:8080/api/v1` — реального деплоя пока
    нет, так что локальный backend это честная текущая правда. Полноценный
    dev/staging/prod-переключатель (flavors/--dart-define) — когда
    появится настоящее окружение, под которое переключаться.
- **Vertical-фильтр в UI пока не выведен** (бэкенд его поддерживает) — нет
  ещё концепции выбора vertical в UX, придумывать её сейчас было бы
  забеганием вперёд.
- Тесты виджетов (`test/features/discovery/discovery_screen_test.dart`) —
  happy path и пустой результат, через override `discoveryApiProvider`
  фейковым подклассом (без реальной сети). Старый `test/widget_test.dart`
  (общий smoke-тест) обновлён — теперь он реально доходит до
  `DiscoveryScreen` через роутинг, поэтому ему тоже нужен override
  `networkConfigProvider` + `discoveryApiProvider` (раньше smoke-тест
  ничего не тестировал по сути, т.к. ни один виджет не обращался к сети).
- `flutter analyze` — чисто, `flutter test` — 3/3 (было бы сломано без
  фикса smoke-теста).
- `flutter build apk --debug` — собирается.
- **Живая проверка в браузере** (по правилу "для UI - открыть и
  проверить, а не просто верить тестам"): `flutter run -d windows` не
  сработал (нет Visual Studio C++ toolchain на машине), поэтому
  использовал `flutter run -d chrome`. Веб-запрос упёрся в CORS — backend
  не разрешал кросс-origin запросы с `localhost:5758` на `localhost:8080`.
  Добавлен `backend/platform-api/.../WebConfig.java` — permissive CORS
  только для `http://localhost:*`, только чтобы дать локальной веб-версии
  достучаться до локального backend; нужно ужесточить/убрать перед первым
  реальным деплоем. После фикса — реальные данные с backend отрисовались
  в UI, подтверждено скриншотом (отправлен пользователю).
- **Находка**: `MainWindowHandle` у нескольких Chrome-инстансов,
  запущенных `flutter run -d chrome` с разными `--user-data-dir`,
  выглядит одинаково через `Get-Process | Where MainWindowTitle`
  (неоднозначно, если открыто больше одного `flutter run -d chrome`) —
  пришлось сопоставлять PID через `wmic process ... get CommandLine` по
  `--remote-debugging-port`, чтобы найти окно нужного запуска. На будущее:
  указывать разные `--web-port` и не запускать параллельно несколько
  `flutter run -d chrome`, если нужен скриншот конкретного инстанса.

### Текущий статус
Всё застейджено (backend `WebConfig.java` + Flutter feature), **не
закоммичено** — ждём подтверждения.

Phase 2 (backend шаги 1-4 + Flutter browse-UI шаги 5-6) полностью
завершена, закоммичена и запушена (`173d08b`).

## Auth-модуль (сделано, 2026-08-19)

Сверился с Factory Blueprint §14 (roadmap): auth формально числится
частью **Phase 1** ("repo, core_network/ui/auth/profile — строить вместе
с реальными экранами"), но в Phase 1 этой сессии реально был создан
только пустой каркас модуля — сам auth не строился. Без него booking-UI,
favorites-UI и отправка отзывов из приложения физически не могут
работать (нет "текущего пользователя"). Пользователь подтвердил
"двигаться по плану" — строю auth сейчас, закрывая пропуск, а не
отдельной пронумерованной фазой (в таблице roadmap отдельной фазы под
auth после Phase 2 нет — она и должна была быть частью Phase 1).

- `Credential` (модуль `auth`, таблица `credential`) — намеренно отдельно
  от `users.User` (это уже было заложено в ERD на Phase 1: "auth —
  учётные данные/токены — отдельно от USER"). `password_hash` через
  BCrypt (`spring-security-crypto`, **не** полноценный
  `spring-boot-starter-security`) — последний включил бы authentication
  filter chain на все endpoint'ы по умолчанию и потребовал бы
  переконфигурировать каждый уже написанный контроллер/тест. Собственный
  `JwtAuthFilter` — гораздо меньшее изменение, соответствует прямой
  формулировке Blueprint §12: "собственный JWT access/refresh".
- `RefreshToken` — хранится **хэш** (SHA-256) токена, не сам токен (та же
  гигиена, что у паролей). Ротация при каждом использовании (старая
  запись удаляется, выдаётся новая) — без полноценной token-family/
  reuse-detection схемы (это OAuth-уровня сложность, не оправдана для
  MVP без истории атак).
- `JwtService` — HMAC-SHA512 (через `io.jsonwebtoken:jjwt` 0.13.0),
  access-токен 30 минут, refresh — 30 дней (настраиваемо через
  `app.jwt.*` в `application.yml`). Секрет пока лежит прямо в
  `application.yml` (dev-значение, закоммичено осознанно) — обязательно
  вынести в env var/secret manager перед реальным деплоем (Phase 7
  Production по roadmap).
- `JwtAuthFilter` — **не** глобальный gate "защитить всё". Просто
  прокидывает `userId`/`role` в атрибуты запроса, если валидный Bearer
  token присутствует; какие endpoint'ы требуют auth — решает каждый
  endpoint сам (пока только `GET /api/v1/auth/me`). Полноценная политика
  доступа по ролям — решение на будущее, когда защищённых endpoint'ов
  наберётся достаточно, чтобы формулировать политику осмысленно.
- Endpoints: `POST /api/v1/auth/register`, `POST /api/v1/auth/login`,
  `POST /api/v1/auth/refresh`, `GET /api/v1/auth/me`.
- `auth` module имеет прямую Gradle-зависимость на `users` (создаёт
  `User` в той же транзакции при регистрации) — та же логика исключения,
  что у `reviews → booking`: это не просто ссылка по ID, а владение
  инвариантом ("аккаунт создан правильно").
- **Известный оставшийся разрыв, специально не трогал**: старый
  `POST /api/v1/users` (создание `User` без пароля/Credential) всё ещё
  существует и используется тестами (`ProviderApiTests` и т.д.) как
  быстрый способ создать тестового пользователя. Теперь это дублирующий,
  небезопасный путь создания аккаунта в обход `/auth/register` — не стал
  убирать/защищать его в этом шаге, чтобы не переписывать все
  существующие тесты; для реального продукта этот endpoint нужно будет
  либо убрать, либо ограничить только на `platform_admin`.
- Flyway `V7` (`credential`, `refresh_token`).
- Тесты на реальном Postgres (Testcontainers): `AuthApiTests` — полный
  цикл register → me → login (неверный/верный пароль) → refresh (ротация,
  повторное использование старого токена отклоняется) → дубль email.
- Вручную проверено: `docker compose up postgres` + `bootRun` + curl —
  все сценарии подтверждены кодами ответа как задумано.
- `./gradlew build` — BUILD SUCCESSFUL.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

**Auth-backend закоммичен и запушен** (`b4da44f`).

## Auth во Flutter (сделано, 2026-08-19)

- `packages/core_network` расширен: `AuthTokenHolder` (простой mutable
  держатель access-токена) + `authTokenHolderProvider`. `dioProvider`
  читает его в интерцепторе и подставляет `Authorization: Bearer` в
  каждый запрос, если токен есть. core_network по-прежнему ничего не
  знает про login/регистрацию — тот же паттерн "app переопределяет, Core
  не в курсе", что уже применялся для `NetworkConfig`.
- `apps/user_app/lib/features/auth/`:
  - `data/` — `AuthApi` (register/login/refresh/me поверх `DioClient`,
    `AuthException` с человекочитаемыми сообщениями для 401/409),
    `TokenStorage` (обёртка над `SecureStorageService` из `core_storage`
    — access/refresh токены в secure storage, не в обычном хранилище).
  - `presentation/providers/auth_providers.dart` — `AuthController`
    (`AsyncNotifier<UserSummary?>`, `null` = не залогинен). При старте
    (`build()`) пробует сохранённый access-токен через `/me`; если не
    вышло — пробует `refresh` сохранённым refresh-токеном (тихий
    re-login); если и это не вышло — чистит storage, возвращает `null`.
    **Осознанно не реализован** retry-с-refresh на каждый отдельный
    401 посреди сессии — это добавило бы заметную сложность
    (concurrency, избежание storm-refresh), не оправданную сейчас, когда
    ещё нет ни одного реального защищённого пользовательского флоу
    (booking), который мог бы столкнуться с истечением 30-минутного
    access-токена посреди использования.
  - `presentation/screens/` — `LoginScreen`, `RegisterScreen` (всегда
    роль `CUSTOMER` — `PROVIDER_OWNER` регистрируется через будущий
    Business Admin, не через этот app, см. Factory Blueprint §11).
  - `ProfileScreen` переписан: раньше — статичная заглушка, теперь —
    реальный logged-out/logged-in вид (`authControllerProvider.when`),
    с кнопками Log in / Create an account / Log out.
- Тесты: `test/features/auth/auth_controller_test.dart` — 5 тестов на
  `AuthController` через `ProviderContainer` с фейковыми `AuthApi` и
  in-memory `SecureStorageService` (по тому же паттерну подкласса, что
  `DiscoveryApi`/`_FakeDiscoveryApi`): старт без сессии, успешный login
  (токены сохранены, `AuthTokenHolder` обновлён), неудачный login
  (ошибка, токены не сохранены), восстановление сессии по сохранённому
  токену, logout (всё очищено). `flutter analyze` — чисто, `flutter
  test` — 8/8 (5 auth + 2 discovery + 1 smoke).
- **Живая проверка в браузере** (`flutter run -d chrome` + реальный
  backend): полный цикл register → автоматический вход (имя/email видны,
  кнопка Log out) → logout → снова экран входа — подтверждено
  скриншотами, отправленными пользователю. По пути поймал и исправил
  свою же ошибку автоматизации: `SendKeys` интерпретировал `+` в номере
  телефона как модификатор Shift — исказило тестовый ввод, но это баг
  скрипта тестирования, не приложения.
- **Находка**: при первом запуске `flutter run -d chrome` в этой сессии
  однажды столкнулись с `Failed to fetch dynamically imported module:
  https://www.gstatic.com/flutter-canvaskit/.../canvaskit.js` — похоже на
  разовый сетевой сбой при загрузке CanvasKit-рендерера с CDN (тот же
  CDN до и после отрабатывал нормально в этой же сессии). Если повторится
  — просто перезапустить `flutter run`, не искать более глубокую причину
  сразу.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

**Auth во Flutter закоммичен и запушен** (`1329bb7`).

## Booking-UI (сделано, 2026-08-20)

- Новая фича `apps/user_app/lib/features/booking/`:
  - `data/models/` — `AvailabilitySlot`, `Booking` (без кодогена, как и
    в `discovery`/`auth` — тот же осознанный выбор).
  - `data/booking_api.dart` — `BookingApi.listAvailabilitySlots`,
    `createBooking`, `listMyBookings`; `BookingException` даёт
    человекочитаемое сообщение на `409` ("слот только что заняли").
  - `presentation/screens/provider_detail_screen.dart` — услуги провайдера
    (из `ProviderSearchResult`, уже есть у `DiscoveryScreen`) +
    живой список открытых слотов (`GET .../availability-slots`).
    Выбор услуги — через новый Flutter-виджет `RadioGroup<T>` (Flutter
    3.32+), а не deprecated `RadioListTile.groupValue/onChanged`.
  - `presentation/screens/my_bookings_screen.dart` — список броней
    пользователя (`GET /users/{id}/bookings`), доступен из
    `ProfileScreen` кнопкой "My bookings" (только когда залогинен).
  - `ProviderCard` (discovery) получил опциональный `onTap` — переход на
    деталку провайдера остаётся decoupled от booking-фичи (discovery не
    зависит от booking, навигацию собирает `DiscoveryScreen`).
- **Реальный баг, найденный через флакающийся тест**: `_book()` сначала
  читал `ref.read(authControllerProvider).value` синхронно. Если это
  первое обращение к `authControllerProvider` за всё время сессии
  приложения (пользователь ни разу не открывал вкладку Profile) —
  `AsyncNotifier.build()` ещё не успевает выполниться синхронно, `.value`
  на свежесозданном `AsyncLoading` равен `null`, и реально залогиненного
  пользователя ошибочно кидало на экран логина. Виджет-тест был flaky
  (падал/проходил в зависимости от того, что происходило до него) —
  расследование флакающегося теста вскрыло настоящий продовый баг, а не
  проблему самого теста. **Исправлено**: `await
  ref.read(authControllerProvider.future)` — дожидается реального
  результата вместо гонки за снимком состояния. Пять последовательных
  прогонов теста после фикса — стабильно зелёные.
- Тесты: `provider_detail_screen_test.dart` (выбор услуги+слота включает
  кнопку Book и отправляет правильные данные; пустой список слотов
  показывает сообщение), `my_bookings_screen_test.dart` (пустое
  состояние; рендер цены/статуса брони) — оба через паттерн
  fake-подкласса API, без реальной сети. `flutter analyze` — чисто,
  `flutter test` — 12/12.
- **Живая проверка в браузере** (backend + `flutter run -d chrome`):
  полный цикл — открыл деталку провайдера → выбрал услугу и слот → Book
  без логина корректно перекинул на экран входа → зарегистрировался →
  повторил выбор и Book → бронь реально создалась → подтверждено на
  экране "My bookings" ($25.00, CONFIRMED). Скриншоты отправлены
  пользователю.
- **Известный UX-пробел, найден и осознанно не чиним в этом шаге**: после
  логина/регистрации *посреди* попытки забронировать пользователя
  возвращает на Discover, а не обратно на экран провайдера с сохранённым
  выбором услуги/слота — потому что `LoginScreen`/`RegisterScreen`
  используют `popUntil((route) => route.isFirst)` в рамках навигатора
  вкладки Home, и "первый" маршрут там — `DiscoveryScreen`, а не
  `ProviderDetailScreen`, с которого начался вход. Не баг корректности
  (бронирование всё равно нужно подтвердить повторным нажатием Book),
  но требует лишнего шага от пользователя. Исправление — прокинуть
  "вернуться сюда после входа" через результат `Navigator.push` вместо
  `popUntil`, оставлено на будущий полировочный проход.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

**Booking-UI закоммичен и запушен** (`c2028a0`).

## Отзывы из приложения (сделано, 2026-08-20)

Выбрано вместо favorites: backend отзывов уже полностью готов и
протестирован (Phase 2, шаг 3), а этот шаг естественно продолжает только
что собранный экран "My bookings" — closing the loop browse → book →
review из MVP-сценария (Factory Blueprint §6). Favorites потребовал бы
писать новый backend-модуль с нуля.

- Новая фича `apps/user_app/lib/features/reviews/`:
  - `data/models/review.dart`, `data/reviews_api.dart` — `getReview`
    (404 трактуется как нормальное состояние "отзыва ещё нет", не
    ошибка, возвращает `null`), `createReview`. `ReviewException` даёт
    читаемые сообщения на `409`/`400`.
  - `presentation/widgets/review_section.dart` — `ReviewSection`
    (звёзды + комментарий, если отзыв есть; кнопка "Leave a review",
    если нет) и `_LeaveReviewDialog` (выбор рейтинга 1-5 через
    `IconButton`-звёзды, комментарий опционален).
- `MyBookingsScreen`: `ReviewSection` показывается только для
  бронирований в статусе `COMPLETED` — соответствует backend-правилу
  "no review without a verified visit".
- Тесты: `review_section_test.dart` (4 теста — кнопка без отзыва, показ
  существующего отзыва, успешная отправка через диалог, читаемая ошибка
  при неудаче) + новый тест в `my_bookings_screen_test.dart` (секция
  отзыва видна только для `COMPLETED`). `flutter analyze` — чисто,
  `flutter test` — 17/17.
- **Живая проверка в браузере**: зарегистрировал пользователя и создал
  завершённую бронь через API (`.../complete`, т.к. в UI пока нет способа
  завершить бронь — это действие бизнеса, Business Admin ещё не
  построен), залогинился в приложении этим пользователем, открыл My
  bookings → "Leave a review" → поставил 4 звезды и комментарий → Submit
  → отзыв реально сохранился на backend и отобразился на экране.
  Скриншоты отправлены пользователю.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

**Отзывы закоммичены и запушены** (`eb2b8db`).

## Favorites (сделано, 2026-08-20)

Последний пункт Phase 2 по roadmap-таблице Blueprint, требовавший нового
backend-модуля с нуля (в Phase 1 модуль не был даже заскаффолжен, в
отличие от auth/users/providers/services/booking/payments/reviews/
notifications/search).

### Backend — новый модуль `favorites`
- `Favorite` (id, userId, providerId, createdAt), уникальный индекс
  `(user_id, provider_id)` — двойной избранный тот же провайдер
  невозможен на уровне БД, не только в приложении.
- Read-композиция над `providers`/`services`/`booking` — та же
  архитектурная логика, что у `search` (см. `favorites/build.gradle.kts`):
  запрос, не проверка инварианта, поэтому прямая Gradle-зависимость
  оправдана. **`favorites` не зависит от `search`** — оба читают Layer 1
  независимо (сестринские модули на уровне Discovery/Trust по слоям
  Blueprint), не должны знать друг о друге.
- `FavoriteDtos.FavoriteProviderResponse` — та же форма, что и
  `search`'ного `ProviderSearchResult` (+`favoritedAt`), намеренно не
  расшарена между модулями как общий тип — небольшое дублирование лучше,
  чем странная межмодульная зависимость.
- Endpoints: `POST/DELETE/GET /api/v1/users/{userId}/favorites/{providerId}`
  (add/remove/check — все **идемпотентны**, повторный `POST` уже
  избранного или `DELETE` не избранного не ошибка), `GET
  /api/v1/users/{userId}/favorites` (список с полной инфой о провайдере).
  `GET .../favorites/{providerId}` — 404, если не в избранном (тот же
  паттерн, что `reviews.getReview`).
- Flyway `V8` (`favorite`).
- Тест `FavoritesApiTests` на реальном Postgres — favorite → check →
  list → unfavorite → check, плюс явная проверка идемпотентности (add/
  remove дважды подряд не падают). Вручную проверено через `bootRun` +
  curl — все сценарии подтверждены кодами ответа.

### Flutter — новая фича `features/favorites/`
- `FavoritesApi` (list/check/add/remove) переиспользует
  `ServiceSummary` из `discovery` вместо дублирования идентичной модели.
- Добавлен `DioClient.delete()` в `core_network` — раньше был только
  `get`/`post` (в коде уже был комментарий-заготовка "add delete, etc.").
- `FavoriteButton` — сердечко-toggle в AppBar `ProviderDetailScreen`, тот
  же гейт на логин, что у кнопки "Book" (не залогинен → экран входа).
  Использует `((userId, providerId))` Dart record как ключ
  `FutureProvider.family` — структурное равенство из коробки, без
  написания класса-ключа вручную.
- `FavoritesScreen` — список избранного, доступен из `ProfileScreen`
  ("My favorites", рядом с "My bookings", только когда залогинен).
- Тесты: `favorite_button_test.dart` (гейт на логин, показ/переключение
  filled↔outline, вызовы add/remove) + `favorites_screen_test.dart`
  (пустое состояние, рендер карточки). `flutter analyze` — чисто,
  `flutter test` — 22/22.
- **Живая проверка в браузере**: полный цикл — открыл провайдера,
  нажал сердечко (залогинен) → красное сердечко → зашёл в "My
  favorites" → провайдер реально там. По пути поймал **собственную
  ошибку тестирования, не баг приложения**: один прогон клика по
  сердечку показал экран логина хотя я думал, что уже вошёл — оказалось,
  предыдущий клик по кнопке "Log in" не был подтверждён скриншотом и,
  похоже, форма отправилась до того, как поля заполнились. Пересдал
  логин с проверкой скриншотом — дальше всё отработало верно. Урок:
  всегда проверять состояние скриншотом после логина перед тем, как
  полагаться на него в следующих шагах сценария.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

## Phase 2 — итог
**Backend и Flutter UI полностью завершены** для всех пунктов Phase 2 по
Blueprint-таблице, кроме **maps** (карты/гео) — единственный
сознательно отложенный пункт, требующий решения пользователя о внешнем
провайдере (Google Maps/Mapbox/OSM) и API-ключах/биллинге, которое не
принимается архитектором в одностороннем порядке.

Полный MVP-цикл теперь работает end-to-end и живьём проверен в браузере
на каждом шаге: **регистрация/вход → поиск провайдера → просмотр →
избранное → бронирование → отзыв после визита**.

## Phase 3 — Commerce (сделано на mock-провайдере, 2026-08-20)

Пользователь выбрал: строить payments сейчас, но на **mock-провайдере**
вместо реального Stripe — у проекта пока нет Stripe-аккаунта/API-ключей
(создать который может только пользователь, не я). Архитектура спроектирована
так, чтобы подключить настоящий Stripe позже было заменой одного класса,
а не редизайном.

### Ключевое архитектурное решение: не трогать state machine бронирования
Blueprint §12 явно требует: "состояние booking — явная state machine,
источник истины — webhook от провайдера, не клиент". Это правильный
долгосрочный дизайн (booking должен ждать реального асинхронного webhook
перед переходом в CONFIRMED), но строить его сейчас означало бы городить
webhook-хореографию без реального webhook на другом конце. Вместо этого:
**booking полностью сохранил свой текущий, уже протестированный flow**
(сразу CONFIRMED, как в Phase 2) — payments подключены как отдельный,
следующий шаг после создания брони, а не как гейт перед ней. Когда
появится реальный Stripe с настоящими асинхронными webhook'ами, тогда и
имеет смысл вводить полноценный "booking ждёт оплаты" state machine —
не раньше.

### Backend — модуль `payments` (был пустым каркасом с Phase 1)
- `Payment` (bookingId — unique, amount, currency, status, providerReference,
  failureReason, createdAt/updatedAt). Один платёж на бронирование —
  **не частичный депозит с процентом, а полная сумма**. Разбивка
  "депозит vs полная оплата" — бизнес-политика, которую я сознательно не
  придумывал сам (нет продуктового требования на конкретный %); оставлена
  как решение на будущее.
- `PaymentProvider` — порт (интерфейс) в духе Stripe: `charge(...)` →
  `ChargeResult`, `refund(...)` → `RefundResult`. Задокументировано прямо
  в коде: реальный провайдер должен возвращать pending/requires-action и
  подтверждать через webhook; mock резолвится синхронно, потому что ждать
  пока нечего.
- `MockPaymentProvider` — единственная реализация, всегда успешна,
  генерирует `mock_pi_<id>` вместо настоящего Stripe PaymentIntent id.
  Комментарий в коде: заменить на реализацию поверх `stripe-java`,
  спрятанную за Spring-профилем/условным бином, когда появятся ключи —
  остальной код меняться не должен.
- `payments` зависит от `booking` (та же логика, что `reviews → booking`:
  нужно прочитать сумму и подтвердить существование брони).
- Endpoints: `POST /api/v1/bookings/{bookingId}/payments` (создать и сразу
  списать), `GET /api/v1/bookings/{bookingId}/payments` (404 = ещё нет
  оплаты — тот же паттерн, что у reviews/favorites), `POST
  /api/v1/payments/{id}/refund`. Повторная оплата уже оплаченной/pending
  брони — `409`. Возврат неуспешного (не `SUCCEEDED`) платежа — `409`.
- `app.payments.currency: USD` в `application.yml` — единая валюта на
  платформу (см. Blueprint MVP: "один рынок"), без per-сервисного lookup.
- Flyway `V9` (`payment`). Тест `PaymentsApiTests` на реальном Postgres —
  оплата → повторная оплата отклонена → refund → повторный refund
  отклонён. Вручную проверено через `bootRun` + curl — все сценарии
  подтверждены кодами ответа.

### Flutter — новая фича `features/payments/`
- `PaymentsApi` (`getPayment` — 404 = null, `createPayment`).
- `ProviderDetailScreen._book()`: сразу после успешного создания брони
  вызывает `paymentsApi.createPayment(booking.id)` в том же флоу, показывает
  объединённое сообщение ("Booking confirmed and paid!" или, если оплата
  не удалась — какая часть). Booking создаётся и подтверждается
  независимо от результата оплаты (соответствует backend-решению не
  гейтить booking через payment).
- `PaymentStatusChip` — статус оплаты рядом со статусом брони в `My
  bookings` (не активный элемент — списание происходит только один раз,
  сразу при бронировании, не по кнопке).
- Тесты: обновлены `provider_detail_screen_test.dart` (теперь также
  проверяет вызов оплаты и итоговое сообщение) и `my_bookings_screen_test.dart`
  (добавлен fake `PaymentsApi` во все кейсы, т.к. чип теперь всегда
  рендерится), plus новый `payment_status_chip_test.dart`. `flutter
  analyze` — чисто, `flutter test` — 24/24.
  - Попутный фикс теста: `Navigator.pop()` после показа `SnackBar`
    возвращал на `home: SizedBox()` без `Scaffold` — `SnackBar` физически
    негде было отрендерить. Обернул тестовый `home` в `Scaffold`.
- **Живая проверка в браузере**: полный цикл — вход → поиск → бронирование
  → автоматическое списание → в "My bookings" бронь `CONFIRMED` +
  зелёный чип `Payment: SUCCEEDED`. Скриншот отправлен пользователю.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

**Phase 3 (payments на mock) закоммичена и запушена.**

## Maps/геолокация на mock-провайдере (сделано, 2026-08-20)

Пользователь выбрал: "давай maps тоже на моках" — та же архитектура
port/adapter, что уже применялась для payments (Phase 3): реальные
данные и математика (координаты, расстояние) не мокаются — мокается
только то, что реально требует внешний аккаунт (рендеринг карты,
геолокация устройства пользователя).

### Backend
- `Provider` (модуль `providers`) получил nullable `latitude`/`longitude`
  — задаются напрямую вызывающей стороной, без шага геокодирования по
  адресу (адреса у `Provider` нет вообще; геокодирование отложено вместе
  со всем остальным, что требует реального провайдера карт). Старый
  6-аргументный конструктор оставлен как есть, делегирует в новый
  8-аргументный с `null, null` — ни один существующий вызов/тест не
  сломан.
- `CreateProviderRequest` расширен до `(ownerUserId, name, vertical,
  latitude, longitude)` + добавлен compact-конструктор с 3 аргументами
  (старая форма) — тот же приём, что уже использовался в Phase 1/2 для
  обратной совместимости DTO без дублирования тест-кода.
- Flyway `V10` — `latitude`/`longitude` (`double precision`, nullable) в
  таблице `provider`.
- `search`-модуль: новый `DistanceCalculator` (package-private,
  Haversine, чистая математика, без внешних зависимостей) +
  `SearchService.search(vertical, query, originLat, originLng)` —
  сортировка теперь **availability desc → distance asc (null → в конец)
  → price asc**, ранее реализованный rating остаётся неготовым (как и
  раньше — материализованная read-модель, не для MVP). `distanceKm`
  считается только когда есть и origin, и координаты провайдера;
  координаты провайдера всегда возвращаются в результате поиска.
  `GET /api/v1/search/providers` получил опциональные `lat`/`lng`.
- Тест `SearchApiTests.ranksByDistanceWhenTheCallerSuppliesItsLocation` —
  ближний провайдер ранжируется раньше дальнего при заданном origin.
  Находка: `assertThat((Number) ...).isLessThan((Number) ...)` не
  компилировался (AssertJ не резолвил числовой overload через `Object`-
  каст) — исправлено через промежуточные `double`-переменные.
- Вручную проверено через `bootRun` + curl: `distanceKm` считается верно
  (~1.49 км рядом, ~972 км до Астаны) и корректно `null`, если origin не
  передан.

### Flutter — новая фича `features/maps/`
- `GeoPoint` (value object) + `LocationService`/`MockLocationService`
  (интерфейс в духе `PaymentProvider` — задокументировано, что реальная
  реализация подключится через пакет `geolocator`, тем же
  drop-in-заменой класса за интерфейсом). Мок всегда возвращает
  фиксированную точку в Алматы.
- `MockMapScreen` — заглушка вида карты (иконка, "Map view placeholder",
  пояснительный текст про отложенный реальный SDK, координаты,
  "X.X km from you", если дистанция известна).
- `discovery_providers.dart`: `searchResultsProvider` перед запросом
  пытается получить `currentLocationProvider` (через `MockLocationService`),
  ошибку геолокации проглатывает (origin остаётся `null`, поиск всё равно
  работает — деградация, а не отказ).
- `ProviderCard` показывает "X.X km away", если `distanceKm` не `null`.
- `ProviderDetailScreen` получил кнопку "View on map" (видна только если
  у провайдера есть координаты), открывающую `MockMapScreen`.
- Тесты: `location_service_test.dart`, `mock_map_screen_test.dart` (полный
  рендер + пропуск дистанции, если не передана), плюс обновлены сигнатуры
  fake-подклассов `DiscoveryApi` в `discovery_screen_test.dart` и
  `widget_test.dart` (добавлены опциональные `lat`/`lng` — иначе
  `invalid_override`). `flutter analyze` — чисто, `flutter test` — 27/27.
  `flutter build apk --debug` — собирается.
- **Живая проверка в браузере**: посеял через curl "Close By Salon"
  (43.25, 76.90) и "Far Away Salon" (51.1694, 71.4491 — Астана) с
  открытым API-подтверждением `distanceKm` (1.49 км и 972.25 км
  соответственно). На экране Discover карточка "Close By Salon" реально
  показывает "1.5 km away" в правильной позиции сортировки. Открыл
  деталку провайдера → кнопка "View on map" видна → нажал → `MockMapScreen`
  корректно отрисовала заглушку, координаты "43.2500, 76.9000" и
  "1.5 km from you". Скриншоты отправлены пользователю. Окружение
  (Chrome/Dart/Java-процессы, `docker compose`) остановлено после
  проверки.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

### Текущий статус
Phase 2 полностью закрыта, включая maps на mock-провайдере.

## Phase 4 — Beauty vertical: masters, портфолио, правило бронирования (сделано, 2026-08-20)

Первая настоящая vertical-специфика поверх уже построенного generic-ядра
— практическая проверка принципа "Core не знает про vertical" из
`docs/erd/core-domain.md`.

### Backend — новый Gradle-модуль `vertical-beauty`
- Новый модуль назван с префиксом `vertical-` (не просто `beauty`, как
  остальные bounded-context модули) — явно маркирует его как модуль
  третьего слоя (Core/Marketplace/Vertical из Factory Blueprint), а не
  как ещё один bounded context. Пакет `com.zairo.factory.vertical.beauty`.
- `Master` (`beauty_master`: providerId, displayName, bio, photoUrl,
  active), `PortfolioItem` (`beauty_portfolio_item`: masterId, imageUrl,
  caption), `MasterServiceLink` (`beauty_master_service`: связь
  master↔service, unique-пара — назван не `MasterService`, чтобы не
  конфликтовать с Spring-стереотипом `@Service`, та же причина, что у
  `ServiceOffering`), `MasterBooking` (`beauty_master_booking`: bookingId
  unique + masterId — какой мастер связан с какой Core-бронью).
- **Единственное место, где этот модуль читает `Provider.vertical`**:
  `MasterDirectoryService.createMaster` отказывает (400), если
  провайдер не в vertical `"beauty"`. Это vertical-модуль проверяет своё
  собственное предусловие, а не Core ветвится по vertical — сам модуль
  `providers` по-прежнему нигде не смотрит на эту строку.
- **Правило бронирования**: `BeautyBookingService.createBooking`
  проверяет, что названный мастер реально привязан (`MasterServiceLink`)
  к запрошенной услуге, иначе `409 MasterDoesNotOfferServiceException`
  — и только потом вызывает **Core-сервис `BookingService.createBooking`
  напрямую** (не просто его репозиторий, как делают reviews/payments) —
  чтобы переиспользовать атомарный захват слота (`OPEN → BOOKED` с
  `@Version`) вместо повторной реализации этой логики и риска рассинхрона
  с Core / повторного race на двойное бронирование. Это новый прецедент
  межмодульной зависимости (vertical → Core *service*, не только
  *repository*), задокументированный в `vertical-beauty/build.gradle.kts`.
- `linkService`/`unlinkService` идемпотентны (тот же паттерн, что у
  favorites), с проверкой, что услуга принадлежит тому же провайдеру,
  что и мастер (400 иначе).
- Endpoints: `POST/GET /api/v1/beauty/providers/{id}/masters`,
  `GET /api/v1/beauty/masters/{id}`, `POST/GET .../portfolio`,
  `POST/DELETE/GET .../services/{serviceId}`,
  `POST /api/v1/beauty/bookings`, `GET /api/v1/beauty/bookings/{id}`.
  Отдельный URL-префикс `/api/v1/beauty/...` — Core-эндпоинты (`/bookings`
  и т.д.) не знают о существовании vertical-namespace.
- Flyway `V11`-`V14`. Тест `BeautyApiTests` на реальном Postgres: отказ
  создания мастера на non-beauty провайдере (400), полный флоу
  master→portfolio→booking rule (409 до линковки → link → 201 после) →
  получение брони через beauty-эндпоинт → идемпотентность link/unlink.
  Находка: тест изначально использовал `"beauty-" + runId` как vertical
  (по аналогии с SearchApiTests) — но `MasterDirectoryService` сверяет
  **точный** литерал `"beauty"`, не префикс; поправлено на буквальное
  значение, коллизий с параллельными тестовыми классами не возникло (это
  не самый широкий "list all" запрос, как у search).
- Вручную проверено через `bootRun` + curl: создание мастера/портфолио,
  409→link→201 для правила бронирования, 400 для non-beauty провайдера —
  все сценарии подтверждены кодами ответа.

### Flutter — новая фича `features/beauty/`
- `BeautyApi` (`listMasters`, `listPortfolio`, `createBeautyBooking`).
  `createBeautyBooking` вручную мапит JSON-ответ (`bookingId`+`masterId`,
  форма отличается от обычного `Booking`) в тот же `Booking`-класс, что и
  Core-бронирование — остальной flow (оплата, сообщение) не должен знать,
  через какой эндпоинт бронь создана.
- `MasterPortfolioScreen` — грид фотографий с подписями (`Image.network`
  с `errorBuilder`-заглушкой на случай недоступной картинки).
- `ProviderDetailScreen`: если `provider.vertical == 'beauty'`, подгружает
  `mastersProvider` и, если список не пуст, показывает секцию "Masters"
  (тот же `RadioGroup` паттерн, что у выбора услуги) с кнопкой
  "View portfolio" у каждого мастера. Кнопка Book требует выбора мастера
  **только если у провайдера вообще есть мастера** — деградация
  "мастеров нет/запрос не удался → секция не показывается, бронирование
  как раньше" сохраняет обратную совместимость с провайдерами других
  vertical (и с существующими тестами) без веток по vertical в самом
  экране бронирования (кроме одного `if` для решения, дёргать ли
  `mastersProvider`).
  - `_book()`: если мастер выбран — вызывает
    `beautyApi.createBeautyBooking`, иначе — прежний
    `bookingApi.createBooking`. Единственная ветка на весь метод.
  - `BeautyException` (409 — либо мастер не выполняет услугу, либо слот
    только что заняли; backend не различает эти два случая в теле
    ответа, поэтому сообщение общее для обоих).
- Тесты: обновлён `provider_detail_screen_test.dart` — добавлен
  `_FakeBeautyApi` override в оба существующих теста (иначе они бы
  дёргали реальную сеть и подвисали, т.к. экран теперь всегда пытается
  читать `mastersProvider` для `vertical: 'beauty'`), плюс новый тест:
  провайдер с мастерами требует выбора мастера для активации Book и
  бронирует именно через beauty-эндпоинт. Новый
  `master_portfolio_screen_test.dart` (пустое состояние + рендер
  подписи). `flutter analyze` — чисто, `flutter test` — 30/30 (было
  27, +3). `flutter build apk --debug` — собирается.
- **Живая проверка в браузере**: создал через curl салон (vertical
  beauty) с двумя мастерами (Jamie Stylist ↔ Haircut, Sam Nails ↔
  Manicure), портфолио из двух фото для Jamie. На экране провайдера
  секция "Masters" отрисовалась с обоими мастерами; открыл портфолио
  Jamie — грид с двумя фото и подписями отрендерился. Зарегистрировался
  как клиент в приложении, выбрал Jamie + Haircut + слот → кнопка Book
  стала активной только после выбора мастера → нажал Book → "Booking
  confirmed and paid!" → в "My bookings" запись $25.00, CONFIRMED,
  Payment: SUCCEEDED. Скриншоты отправлены пользователю.

### Текущий статус
**Phase 4 (Beauty vertical) закоммичена и запушена** (`13aa19a`).

## Business Admin — новое приложение для владельцев салонов (сделано, 2026-08-20)

Пользователь выбрал "admin ui будем делать" среди предложенных вариантов
(второй vertical vs Business Admin). Как и было заложено ещё на шаге
Auth во Flutter ("PROVIDER_OWNER регистрируется через будущий Business
Admin, не через этот app" — Factory Blueprint §11), это отдельное
Flutter-приложение в монорепо, не раздел внутри `user_app`.

### Backend — два новых read-эндпоинта (остальное переиспользуется)
- `GET /api/v1/users/{ownerUserId}/providers` (модуль `providers`,
  `ProviderRepository.findByOwnerUserId`) — "какие салоны у этого
  владельца".
- `GET /api/v1/providers/{providerId}/bookings` (модуль `booking`) — у
  `Booking` нет своего `providerId` (только `serviceId`/
  `availabilitySlotId`, см. ERD), поэтому список строится через хоп
  `AvailabilitySlotRepository.findByProviderId` → список `slotId` →
  `BookingRepository.findByAvailabilitySlotIdIn` — не денормализованная
  колонка, а композиция на чтение.
- Всё остальное (создание провайдера/услуги/слота, CRUD мастеров/
  портфолио/service-linking, `POST .../bookings/{id}/complete`) — те же
  Core- и vertical-beauty-эндпоинты, что уже использует `user_app`, без
  единой новой backend-строчки бизнес-логики.
- Тест `BusinessAdminApiTests` на реальном Postgres — оба новых
  эндпоинта: список салонов владельца (с "чужим" салоном другого
  владельца, чтобы проверить фильтрацию), список броней провайдера
  (пусто → создание брони → появляется в списке).

### Flutter — новое приложение `apps/business_admin`
- Отдельный `pubspec.yaml` (`name: business_admin`), переиспользует
  `packages/core_network`/`packages/core_storage`, как и `user_app`.
  Платформы ограничены `web,windows,android` (не нужен полный набор
  `flutter create` для внутреннего инструмента).
- **Без go_router/tab-shell** (в отличие от `user_app`) — экраны этого
  приложения линейны (вход → dashboard → один салон за раз), роутер
  добавил бы структуру, которая не нужна. `AuthGate` — корневой виджет,
  переключающий Login/Dashboard по состоянию `authControllerProvider`
  напрямую, без `Navigator.push`/`popUntil`.
- `features/auth/` — дублирует паттерн `user_app` (`AuthApi`,
  `TokenStorage`, `AuthController`, Login/RegisterScreen), но
  **регистрирует роль `PROVIDER_OWNER`** вместо `CUSTOMER` (тот же
  backend-эндпоинт `/auth/register`, разный литерал в каждом приложении
  — сознательно НЕ выносил общий auth в отдельный пакет: два реальных
  потребителя с идентичной логикой — обычно повод для пакета, но объём
  небольшой (~250 строк), а вынос затронул бы уже протестированный код
  `user_app`; можно пересмотреть, если/когда логика начнёт расходиться
  или появится третий потребитель).
- `features/salon/` — модели/`SalonAdminApi` поверх Core-эндпоинтов
  (провайдер, услуги, слоты, брони). Модели названы с префиксом `Admin*`
  (`AdminProvider`, не `Provider`) — иначе конфликт с Riverpod's
  `Provider<T>`.
- `features/beauty/` — `BeautyAdminApi` поверх vertical-beauty
  эндпоинтов (мастера, портфолио, service-linking) — зеркалит
  backend-границу Core/Vertical и на Flutter-стороне: `SalonDetailScreen`
  показывает секцию Masters только когда `provider.vertical == 'beauty'`.
- `DashboardScreen` — список салонов владельца; пустое состояние — форма
  создания салона прямо на экране. **Vertical при создании зашит как
  `'beauty'`** — единственный vertical с реальными admin-экранами
  (мастера/портфолио) на сегодня; выбор vertical станет осмысленным,
  когда появится второй.
- `SalonDetailScreen` — одна прокручиваемая страница с четырьмя
  секциями (Services/Availability/Masters/Bookings), каждая — свой
  `ConsumerWidget`, вотчащий отдельный `FutureProvider.family`. Добавление
  чего-либо — через `AlertDialog` (тот же паттерн `showDialog<bool>` +
  `ref.invalidate` в вызывающей стороне, что и `_LeaveReviewDialog` в
  `user_app`). Портфолио принимает URL картинки, а не загрузку файла —
  в проекте ещё нет подключённого файлового хранилища (S3/MinIO) ни в
  одном admin-флоу; тот же осознанный вырез MVP, что и везде в проекте.
  "Mark complete" у брони со статусом `CONFIRMED` дёргает уже
  существующий `POST /bookings/{id}/complete`.
- Тесты: `auth_controller_test.dart` (4, зеркалит `user_app`, роль
  `PROVIDER_OWNER`), `dashboard_screen_test.dart` (пустое состояние
  создаёт салон; список салонов открывает деталку), `salon_detail_screen_test.dart`
  (добавление услуги вызывает API и обновляет список; "Mark complete"
  вызывает API), `widget_test.dart` (смок-тест до экрана логина).
  9/9 тестов. **Находка**: смок-тест изначально подвесил `pumpAndSettle`
  — в отличие от `user_app`, здесь `AuthGate` — корневой виджет,
  который сразу трогает `authControllerProvider`, а тот читает реальный
  `SecureStorageService` (платформенный канал зависает в тестовом
  окружении без переопределения). Исправлено тем же паттерном, что уже
  есть в `auth_controller_test.dart` — in-memory `SecureStorageService`
  через `secureStorageServiceProvider.overrideWithValue`.
  `flutter analyze` — чисто, `flutter build web` — собирается.
- **Живая проверка в браузере**: зарегистрировался как
  `PROVIDER_OWNER` → автоматический вход → создал салон "Glow UI Salon"
  (beauty) → добавил услугу "Haircut" ($25, 30 мин) → добавил мастера
  "Jamie Stylist" → открыл диалог "Services this master offers",
  отметил чекбокс "Haircut" → **подтверждено через прямой curl-запрос к
  backend**, что `beauty_master_service`-связь реально создалась → добавил
  слот доступности через стандартные Flutter date/time picker'ы (Aug 21,
  13:34) → слот появился в списке "OPEN" → logout корректно вернул на
  экран входа. Скриншоты отправлены пользователю.

### Текущий статус
**Business Admin закоммичен и запушен** (`5072257`).

## Реальная загрузка фото портфолио через MinIO (сделано, 2026-08-20)

Пользователь дал карт-бланш ("дальше продолжай ты сам знаешь что делать")
после коммита Business Admin. Выбрал закрыть самый конкретный и уже
явно задокументированный пробел MVP — портфолио принимало только вручную
вписанный URL картинки — вместо того, чтобы гадать бизнес-правила
непостроенного второго vertical.

### Backend — новый модуль `storage`
- Новый Core-модуль (не vertical-специфичный — заготовка для любых
  будущих загрузок: логотипы провайдеров и т.д.), обёртка над MinIO
  (`io.minio:minio` 9.0.3, версия сверена через Maven Central metadata,
  та же дисциплина, что и раньше в проекте) поверх уже существовавшего,
  но ни к чему не подключённого MinIO из `infrastructure/docker-compose.yml`.
- **Архитектурное решение**: Flutter-приложения НЕ обращаются к MinIO
  напрямую (порт 9000) — только через собственные эндпоинты backend'а
  (`POST /api/v1/uploads` принимает multipart-файл и загружает в MinIO,
  `GET /api/v1/uploads/{key}` стримит байты обратно). Это позволило
  переиспользовать уже готовый CORS (`WebConfig` покрывает `/api/**`) и
  держать креды MinIO целиком на сервере — не пришлось настраивать
  публичную bucket policy и отдельный CORS на самом MinIO, что был бы
  более хрупким и менее контролируемым путём.
- `StorageConfig` создаёт bucket `factory-media` при старте, если его ещё
  нет (dev-удобство, как и другие авто-миграции в проекте).
- Тест `StorageApiTests` на реальных Postgres+MinIO (Testcontainers для
  Postgres, но не для MinIO — тот запускается через
  `docker compose up postgres minio`, тот же паттерн, что у остальной
  dev-инфраструктуры в проекте): загрузка → скачивание → байты совпадают;
  скачивание несуществующего ключа → 404.
- `spring.servlet.multipart.max-file-size/max-request-size: 10MB` —
  разумный лимит по умолчанию.
- Вручную проверено curl'ом: upload → download с правильным Content-Type
  → 404 для несуществующего ключа — все сценарии подтверждены.

### Flutter — `features/storage/` + переработка `AddPortfolioItemDialog`
- Новый `StorageApi` (`business_admin`) — `uploadBytes()` через
  `Dio`'s `FormData`/`MultipartFile.fromBytes`.
- `AddPortfolioItemDialog` переписан: вместо текстового поля URL —
  кнопка "Choose photo" (`file_picker`) с реальным аплоадом.
- **Находка, стоившая большей части этого шага**: `file_picker` 12.0.0
  (последняя стабильная на момент работы) переписал API — `.bytes` поле
  у `PlatformFile` полностью удалено в пользу `readAsBytes()`
  (асинхронный fetch `blob:`-URL). На вебе в этой сессии `readAsBytes()`
  зависал **без исключения и без таймаута** — ни один лог, ни один
  catch-блок ничего не ловил, просто вечный `await`. Диагностировано
  через try/catch вокруг всего пикера (тоже ничего не поймал — значит,
  завис именно `await`, не бросил ошибку) и чтение исходников
  `file_picker_web`. **Исправлено даунгрейдом на конкретный
  пререлиз `12.0.0-beta.1`**: он уже требует `win32 ^6.x` (совместим с
  `flutter_secure_storage` — стабильная линия 8.x требует `win32 ^5.9.0`
  и конфликтует), но ещё не убрал старый синхронный путь
  `pickFiles(withData: true)` → `PlatformFile.bytes`, который отработал
  сразу и надёжно. Если апгрейд `file_picker` понадобится в будущем —
  сначала вручную (не автоматизированно) перепроверить `readAsBytes()`
  на актуальной стабильной версии, возможно баг уже пофикшен выше по
  течению.
- **Находка про автоматизацию тестирования (не про код)**: нативный
  диалог выбора файла Windows — это **отдельное top-level окно**, не
  дочернее окно Chrome — скриншот по `GetWindowRect` окна Chrome иногда
  его не захватывал, если ОС расположила диалог за пределами этого
  прямоугольника. Также столкнулся с Windows' foreground-lock: PowerShell-
  процесс, запущенный без недавнего ввода пользователя, не может
  скрасть фокус через `SetForegroundWindow`/`SwitchToThisWindow` у
  другого приложения — обходится сворачиванием текущего активного окна
  (`ShowWindow(..., SW_MINIMIZE)`) перед тем, как поднимать нужное.
  Оба урока — специфика тестовой автоматизации на этой машине, не имеют
  отношения к коду приложения.
- `flutter analyze` — чисто, `flutter test` — 9/9 (набор тестов не
  менялся, диалог не имел прямого теста на сам file_picker — это
  сторонний нативный API, не мокается юнит-тестами).
- **Живая проверка сквозного сценария** (самое важное здесь): в
  Business Admin выбрал реальный PNG-файл с диска → загрузка →
  `POST /api/v1/uploads` → curl подтвердил, что фото сохранилось в
  MinIO с правильным `Content-Type: image/png` и точным количеством байт
  → URL сохранился в `beauty_portfolio_item.image_url` → **открыл
  портфолио этого же мастера в отдельном, совершенно другом Flutter-
  приложении (`user_app`)** — фото реально отрисовалось. Подтверждает
  весь путь целиком: Business Admin → backend `storage` → MinIO →
  backend отдаёт обратно → рендер в customer-facing app. Скриншоты
  отправлены пользователю.

### Текущий статус
**Загрузка фото через MinIO закоммичена и запушена** (`f59a7dc`).

## Редактирование и удаление в Business Admin (сделано, 2026-08-20)

Пользователь снова дал открытый мандат ("дальше продолжай"). Закрыл
следующий явно отмеченный пробел: раньше владелец мог только *добавлять*
услуги/слоты/мастеров, без возможности исправить опечатку или убрать
лишнее.

### Backend — три новых мутирующих эндпоинта + один найденный попутно баг
- `PUT /api/v1/services/{id}` (обновление title/duration/price/currency),
  `DELETE /api/v1/services/{id}` (**soft-delete**: `active=false`, не
  удаление строки — старые брони по-прежнему ссылаются на `serviceId`).
  Идемпотентно.
- `DELETE /api/v1/availability-slots/{id}` — удалить можно только слот в
  статусе `OPEN` (для `BOOKED` — `409`, переиспользован
  `SlotNotAvailableException`); отмена уже забронированного слота —
  отдельная будущая задача (потребовала бы каскадной отмены брони).
- `DELETE /api/v1/beauty/masters/{id}` — тоже soft-delete
  (`Master.deactivate()`), идемпотентно.
- **Найденный попутно баг**: после того как мастера стали
  деактивируемыми, `MasterRepository.findByProviderId` (без фильтра по
  `active`) продолжал бы показывать "удалённых" мастеров в списке — либо
  в customer-facing бронировании, либо в самом Business Admin.
  Исправлено: `listMastersByProvider` теперь использует
  `findByProviderIdAndActiveTrue` (метод уже существовал, использовался
  в другом месте). **Тот же класс бага сам себя воспроизвёл ещё раз** для
  услуг — `ServiceOfferingController.listByProvider` не фильтровал по
  `active`, из-за чего деактивированная услуга пропадала из поиска
  (search использует `findByProviderIdAndActiveTrue` напрямую через Java-
  композицию), но **оставалась видна в списке Business Admin** — поймано
  живой проверкой в браузере (услуга не исчезала после удаления, хотя
  backend уже вернул `204` и реально проставил `active=false` — curl
  подтвердил расхождение между /search и /providers/{id}/services).
  Исправлено тем же способом. **Урок на будущее**: при добавлении
  soft-delete к любой новой сущности — сразу проверять **все**
  read-эндпоинты этой сущности на фильтр по `active`, не только тот,
  что первым пришёл в голову.
- **Ещё один архитектурный побочный эффект, тоже пойманный живой
  проверкой, не тестами**: подключение `storage`-модуля (предыдущий шаг)
  сделало весь `platform-api`-контекст (а значит — **вообще все**
  `*ApiTests`, не только `StorageApiTests`) зависимым от того, что MinIO
  реально запущен, потому что `StorageConfig.minioClient()` бросал
  исключение при недоступном MinIO прямо на старте контекста Spring.
  Раньше `./gradlew build` требовал только Postgres (его Testcontainers
  поднимает сам); теперь без ручного `docker compose up minio`
  ломались все 18 тестов в модуле, а не один. Исправлено: ошибка
  подготовки bucket'а теперь только логируется (`log.warn`), не валит
  контекст — реальный сбой (если он есть) проявится позже, честно, при
  попытке что-то реально загрузить. `StorageApiTests` — единственный
  тест, которому по-прежнему нужен запущенный MinIO (об этом сказано в
  его javadoc).
- Тесты: новый метод в `ProviderApiTests` (create → update → deactivate
  → deactivate снова идемпотентно), новый метод в `BookingApiTests`
  (удаление OPEN слота ок, удаление BOOKED — 409), новый метод в
  `BeautyApiTests` (деактивация мастера убирает его из листинга,
  повторная деактивация — не ошибка). Все проходят и без MinIO
  (кроме двух `StorageApiTests`, которым он нужен), и с ним — оба режима
  проверены отдельно.
- Вручную через curl — все сценарии (update/deactivate услуги,
  delete open/booked слота, deactivate мастера, идемпотентность) —
  подтверждены кодами ответа и последующим `GET`.

### Flutter (Business Admin) — иконки редактирования/удаления
- `packages/core_network`'s `DioClient` получил `put()` (комментарий-
  заготовка "Add other methods as needed (put, etc.)" уже был в коде —
  наконец понадобился).
- `AddServiceDialog` расширен под режим Add **и** Edit одним виджетом
  (опциональный параметр `existing`) — небольшое переиспользование вместо
  дублирования почти идентичного диалога.
- `SalonDetailScreen`: у каждой услуги — иконки карандаша (открывает
  `AddServiceDialog` в режиме редактирования) и корзины
  (`deactivateService` + `ref.invalidate`); у каждого слота доступности —
  штатный `Chip.onDeleted` (крестик), показывается только для слотов в
  статусе `OPEN` (для `BOOKED` крестика нет — как и на backend, отмена
  брони отдельная тема); у каждого мастера — третья иконка
  (`person_remove_outlined`, `deactivateMaster`).
- Тесты: `salon_detail_screen_test.dart` пополнился двумя методами
  (редактирование услуги вызывает `updateService` с новыми значениями и
  обновляет UI; удаление услуги и слота вызывает нужные API и убирает их
  из списка). 11/11 тестов, `flutter analyze` — чисто,
  `flutter build web` — собирается.
- **Живая проверка в браузере** (полный цикл на уже существующем салоне
  "Glow UI Salon" из прошлых шагов): отредактировал услугу
  ("Haircut" → "Haircut and Style", $25 → $35) — сохранилось; удалил
  открытый слот доступности — исчез из списка; деактивировал мастера
  Jamie Stylist — исчез из списка; удалил услугу — **не исчезла с первой
  попытки**, что и привело к находке бага с фильтром `active` в
  `listByProvider` (см. выше); после фикса и `F5` (полная перезагрузка
  Flutter web-страницы, не hot reload — подтвердило заодно, что сессия
  корректно восстанавливается из secure storage после реального
  перезапуска) — услуга пропала из списка, как и ожидалось. Скриншоты
  отправлены пользователю.

### Текущий статус
**Edit/delete в Business Admin закоммичен и запушен** (`ca654e2`).

## Права владения (ownership authorization) для мутирующих эндпоинтов (сделано, 2026-08-20)

Пользователь выбрал вариант "дальнейшая полировка Business Admin" и
уточнил: "роли/права" — из трёх предложенных архитектором пунктов.
Реальный пробел безопасности: ни один из мутирующих эндпоинтов
(update/delete услуги, delete слота, deactivate мастера — всё, что
добавлено в прошлом шаге) не проверял, что вызывающий действительно
владеет соответствующим провайдером. Любой, у кого есть валидный JWT
(или вообще без токена, поскольку `JwtAuthFilter` — не глобальный gate),
мог отредактировать или удалить чужой салон.

### Архитектурное решение: где живёт проверка владения
- Новый публичный класс `CurrentUser` в модуле `auth`
  (`com.zairo.factory.auth.CurrentUser.requireUserId(HttpServletRequest)`,
  401 если токена нет) — единая точка входа "кто делает этот запрос" для
  любого модуля, не заставляя их знать имя атрибута или трогать JWT
  напрямую.
- Новый `@Component ProviderOwnership` в модуле `providers`
  (`requireOwner(providerId, userId)`, 404 если провайдера нет, 403 если
  принадлежит не ему) — общая логика вместо дублирования в трёх модулях.
- Новые Gradle-зависимости: `services` → `providers` + `auth`,
  `booking` → `providers` + `auth`, `vertical-beauty` → `auth`
  (на `providers` уже была). Та же логика "trust invariant, не просто
  ссылка по id", что и у `reviews → booking` — теперь официально
  распространена на "кто может редактировать чужие данные".
- Защищены: `PUT/DELETE /api/v1/services/{id}`,
  `DELETE /api/v1/availability-slots/{id}`,
  `DELETE /api/v1/beauty/masters/{id}`, а также мутации **существующего**
  мастера — `POST .../portfolio`, `POST/DELETE .../services/{serviceId}`
  (link/unlink).
- **Осознанно НЕ защищено** (задокументировано прямо в коде): все
  `POST`-эндпоинты **создания** (`POST /providers`,
  `POST .../services`, `POST .../availability-slots`,
  `POST .../masters`). Причина — они массово используются как голые
  фикстуры в 8+ тестовых файлах (`SearchApiTests`, `ReviewApiTests`,
  `FavoritesApiTests`, `PaymentsApiTests` и т.д.), которым авторизация
  вообще не по теме; ретрофит auth туда — отдельная, гораздо более
  крупная задача с несоразмерной этому шагу стоимостью. Реальный риск,
  который этот шаг закрывает — это **порча/удаление чужих существующих
  данных**, а не "можно засорить чужой провайдер мусорными записями"
  (это отдельная, менее острая, уже существовавшая дыра, тоже
  зафиксированная как известный остаточный пробел).
- Правило простое: только точное совпадение `owner == user`, без
  ролевого обхода (например, будущий ADMIN bypass) — такого механизма
  ещё нет нигде в проекте, вводить его сейчас было бы преждевременно.

### Тесты
- Обновлены (не расширены количеством методов, а дополнены проверками
  внутри существующих): `ProviderApiTests.updatesThenDeactivatesAService`,
  `BookingApiTests.deletesAnOpenSlotButRefusesToDeleteABookedOne`,
  `BeautyApiTests.fullMasterDirectoryAndBookingFlow`,
  `BeautyApiTests.deactivatingAMasterRemovesItFromTheProviderListing` —
  теперь регистрируют владельца через `/auth/register` (не
  `POST /api/v1/users`, чтобы получить настоящий access-токен), передают
  `Authorization: Bearer` на защищённых вызовах, и явно проверяют, что
  **чужой** зарегистрированный владелец получает `403`.
- `./gradlew build` — BUILD SUCCESSFUL, все тесты проходят (включая
  StorageApiTests с поднятым MinIO).
- Вручную через curl: зарегистрировал двух реальных владельцев (A и B),
  создал провайдера+услугу+слот+мастера под A. Подтверждено кодами
  ответа: без токена — `401`; с токеном B (чужой) — `403` на
  PUT service / DELETE service / DELETE slot / DELETE master; с токеном A
  — успех (`200`/`204`) с реальным сохранением изменений.
- **Живая проверка в браузере** — самое важное: залогинился в Business
  Admin как реальный владелец (тот же flow, что и раньше), добавил
  услугу, отредактировал её через "Edit service" → в логе Flutter
  видно, что `DioClient`'ный interceptor уже автоматически проставлял
  `Authorization: Bearer <token>` на PUT-запросе (ничего не пришлось
  менять во Flutter-коде — авторизация в UI была прозрачна с самого
  начала, поскольку `authTokenHolder` уже обновлялся при логине) — ответ
  backend `200 OK`, диалог закрылся без ошибок. Подтверждает: включение
  серверной проверки владения не сломало ни один существующий UI-флоу
  Business Admin, только закрыло дыру для запросов в обход приложения.
  Скриншот отправлен пользователю.

### Текущий статус
Всё застейджено, **не закоммичено** — ждём подтверждения.

## Следующий шаг — рекомендация архитектора
Business Admin теперь и функционально полон (add/edit/soft-delete), и
защищён на уровне владения. Остаются нетронутыми: авторизация на
create-эндпоинтах (задокументированный, осознанный остаточный пробел),
реактивация деактивированных сущностей, редактирование самого салона.
Дальше на выбор: второй vertical (Auto, Phase 9), дальнейшая полировка
Business Admin, или production hardening (secrets, CORS, реальный
Stripe/maps провайдер перед деплоем) — решение за пользователем.

**Выбор пользователя**: `"пока второй вертикал не нужен давай вариант 2"` —
второй vertical отложен, дальнейшая полировка Business Admin.

---

## Закрытие всех оставшихся пробелов Business Admin (2026-08-20)

Пользователь на вопрос "что из трёх оставшихся пунктов делать" ответил
**`"ничего не оставить сразу сделай все необходимые"`** — сделаны все три
пункта разом, в один проход: (1) авторизация на create-эндпоинтах,
(2) реактивация деактивированных услуг/мастеров, (3) редактирование
самого салона (Provider).

### 1. Авторизация на create-эндпоинтах
Ранее осознанно отложенная дыра (см. предыдущий раздел) закрыта. Теперь
владение проверяется и на создании, не только на edit/delete:
- `POST /api/v1/providers` — требует аутентификации **и** что
  `request.ownerUserId() == текущий пользователь` (403 иначе) — нельзя
  создать провайдера "от имени" другого. DTO не менялся (не стали делать
  `ownerUserId` производным от токена), чтобы не плодить churn.
- `POST /api/v1/providers/{id}/services`,
  `POST /api/v1/providers/{id}/availability-slots`,
  `POST /api/v1/beauty/providers/{id}/masters` — теперь все требуют
  `providerOwnership.requireOwner(providerId, currentUserId)`.
- `MasterDirectoryService.createMaster` — порядок проверок теперь
  **404 (провайдер не найден) → 403 (не владелец) → 400 (не beauty
  vertical)**. Это важно для теста `rejectsMasterCreationOnANonBeautyProvider`:
  чтобы получить именно `400`, а не `403`, токен и провайдер должны
  принадлежать одному и тому же зарегистрированному владельцу.

### 2. Реактивация (симметрично существующему soft-delete)
- `ServiceOffering.reactivate()` / `Master.reactivate()` — обратные
  мутаторы к уже существовавшим `deactivate()`.
- `POST /api/v1/services/{id}/reactivate`,
  `POST /api/v1/beauty/masters/{masterId}/reactivate` — owner-only,
  идемпотентны в смысле "второй вызов тоже 200", но (в отличие от
  deactivate) кидают 404 на несуществующий id, а не тихо no-op.
- Слоты (`AvailabilitySlot`) реактивации **не получили** — они не
  soft-delete, а hard-delete (удаляются только OPEN), реактивировать
  нечего, это осознанное решение, не забытое.
- Новый query-параметр `includeInactive` (default `false`) на
  `GET /api/v1/providers/{id}/services` и
  `GET /api/v1/beauty/providers/{id}/masters` — иначе деактивированные
  сущности вообще ниоткуда не видны и их нечем реактивировать через UI.

### 3. Редактирование салона (Provider)
- `UpdateProviderRequest(name, latitude, longitude)` — **без** `vertical`
  (сменить vertical — осиротить vertical-specific данные типа мастеров
  beauty) и **без** `status` (модерационное поле, у владельца нет права
  сам себе его переключать, админ-консоли для этого пока не существует).
- `PUT /api/v1/providers/{id}` — owner-only.
- Модуль `providers` получил новую Gradle-зависимость на `auth`
  (аналогично тому, как раньше её получили `services`/`booking`/
  `vertical-beauty` — "нужен CurrentUser для проверки владения", тот же
  паттерн, что и `reviews → booking`).

### Тесты (backend)
Все 9 файлов `*ApiTests` в `platform-api` теперь требуют реальной
аутентификации почти на каждом мутирующем вызове — механическая, но
объёмная переработка. Вместо дублирования helper-методов в каждом файле
создан общий `TestAuth` (`registerOwner`, `authHeaders`, record
`Registered`) — заменил три локальные копии одного и того же кода
(`ProviderApiTests`, `BookingApiTests`, `BeautyApiTests`) и добавлен туда,
где авторизации вообще не было (`SearchApiTests`, `ReviewApiTests`,
`FavoritesApiTests`, `PaymentsApiTests`, `BusinessAdminApiTests`).
Добавлены новые проверки: `ProviderApiTests.cannotCreateAProviderOrServiceForSomeoneElse`,
`ProviderApiTests.updatesASalonsNameAndLocationButOnlyTheOwnerCan`,
реактивация внутри `updatesThenDeactivatesAService` и
`BeautyApiTests.deactivatingAMasterRemovesItFromTheProviderListingAndReactivationBringsItBack`.

`./gradlew build` — BUILD SUCCESSFUL, все 18 backend-тестов проходят.

Ручная проверка curl: без токена на create-provider — `401`; с чужим
`ownerUserId` — `403`; deactivate → список пуст → `includeInactive=true`
показывает → reactivate → снова в обычном списке; PUT `/providers/{id}`
меняет имя/координаты и сохраняется.

### Flutter (Business Admin)
- `AdminProvider` — добавлены `latitude`/`longitude` (nullable).
- `SalonAdminApi.updateProvider()`, `.reactivateService()`,
  `listServices(includeInactive:)`.
- `BeautyAdminApi.reactivateMaster()`, `listMasters(includeInactive:)`.
- `providerServicesProvider` / `adminMastersProvider` — семейный ключ
  сменился на Dart-record `(providerId, includeInactive)` (тот же
  паттерн structural-equality-ключа, что и `isFavoritedProvider` в
  `user_app`). Добавлены `showInactiveServicesProvider` /
  `showInactiveMastersProvider` (`StateProvider.family<bool, String>`) —
  тумблер "Show removed" на каждую секцию.
- `SalonDetailScreen` стал `ConsumerStatefulWidget` (хранит локальный
  `_provider`, чтобы AppBar-заголовок обновлялся сразу после
  редактирования без повторного похода на dashboard); добавлена иконка
  "Edit salon" в AppBar → диалог `_EditSalonDialog` (имя/широта/долгота).
  После сохранения инвалидируется и текущий `_provider`, и
  `myProvidersProvider` — список салонов на dashboard тоже обновляется.
  Услуги/мастера в состоянии "removed" показывают серым текстом и кнопку
  "Reactivate" вместо edit/delete.
- Тесты: `dashboard_screen_test.dart` и `salon_detail_screen_test.dart`
  обновлены под новые сигнатуры API (`{bool includeInactive = false}`)
  и дополнены тестами на edit-salon и reactivate service/master.
  Один нюанс: у `_ServicesSection` и AppBar теперь **два** `Icons.edit_outlined`
  на экране — тест editing-a-service переключён с `find.byIcon` на
  `find.byTooltip('Edit')`, чтобы не ловить оба.
- `flutter analyze` — чисто. `flutter test` — 14/14 проходят.
  `flutter build web` — собирается.

### Живая проверка в браузере
Полный цикл на реальном backend + Postgres + MinIO, залогинившись в
Business Admin: создание услуги/мастера через UI (авторизация уже
прозрачна благодаря существующему Dio-интерцептору — во Flutter-коде
менять ничего не пришлось), deactivate → "Show removed" показывает
серым с пометкой "removed" → "Reactivate" возвращает в обычный список —
проверено и для услуги, и для мастера. Редактирование салона: диалог
"Edit salon" открывается с предзаполненными полями, после сохранения
AppBar-заголовок меняется мгновенно (без навигации назад), и на
dashboard список салонов тоже отражает новое имя (подтверждает, что
`myProvidersProvider` инвалидируется корректно). Скриншоты отправлены
пользователю по ходу проверки.

### Статус
Всё реализовано, протестировано (backend + Flutter, юнит + живой
браузер), закоммичено и запушено (`8cdda6a`).

---

## ADMIN-роль доведена до дела: модерация салонов (2026-08-20)

Пользователь попросил сравнить логику с более ранним прототипом
`app_factory` (`C:\Users\Acer\Downloads\app_factory_2\app_factory` —
другой, generic "фабрикой мобильных приложений" проект, не менялся, только
прочитан для сравнения) и спросил, что оттуда взять полезного. Из
предложенного архитектор порекомендовал начать с самого дешёвого и
реально нужного: в проекте уже был объявлен `UserRole.ADMIN`, но нигде не
использовался, а `ProviderStatus` (`PENDING/ACTIVE/SUSPENDED`) висел в
модели данных мёртвым грузом — `search` возвращал провайдеров вне
зависимости от статуса, и ничто никогда не переводило салон из `PENDING`.
Пользователь подтвердил: **"да сделай это"**.

### Закрыта дыра саморегистрации в ADMIN
`AuthDtos.RegisterRequest.role` раньше принимал любое значение enum,
включая `ADMIN`, — любой мог создать себе аккаунт администратора через
`POST /auth/register`. Теперь `AuthService.register()` кидает
`AdminRoleNotSelfAssignableException` (400) при `role == ADMIN`. Как и в
референсном проекте ("выдаётся вручную через БД, см.
`PermissionsService`"), ADMIN-аккаунт создаётся только прямой записью в
`app_user`/`credential` — сознательно без UI/эндпоинта для этого, чтобы не
плодить механизм самоэскалации в новом виде.

### Модерация провайдеров
- `CurrentUser` (модуль `auth`) — добавлены `requireRole(request)` и
  `requireAdmin(request)` (403, если роль в JWT не `ADMIN`) — роль уже
  лежала в токене (`JwtAuthFilter.ROLE_ATTRIBUTE`), просто не была никому
  доступна за пределами `AuthController.me()`.
- `Provider.updateStatus(ProviderStatus)` — новый мутатор, симметричный
  `update()`/`updateStatus` не даёт менять `vertical` (уже было так и для
  обычного `update`).
- `PATCH /api/v1/providers/{id}/status` (admin-only) — единственный способ
  перевести провайдера в/из `PENDING`. `GET /api/v1/providers` получил
  опциональный `?status=` фильтр (для экрана модерации; без параметра —
  как раньше, без ограничений, это НЕ customer-facing путь).
- `SearchService.search()` теперь фильтрует **только `ACTIVE`**
  провайдеров (`ProviderRepository.findByStatus`/`findByVerticalAndStatus`)
  — это единственное реальное следствие фичи: неодобренный или
  suspended-провайдер существует и доступен по прямому id, но невидим в
  discovery.

### Тесты (backend)
Новый `TestAuth.registerAdmin(...)` — в отличие от `registerOwner`,
**не** идёт через `/auth/register` (он теперь блокирует ADMIN), а пишет
`User`+`Credential` напрямую через репозитории (тот же принцип "выдаётся
вручную", просто в тестовом виде), затем логинится за настоящим токеном.
Понадобилась новая `testImplementation("org.springframework.security:spring-security-crypto")`
в `platform-api/build.gradle.kts` — у `auth` эта зависимость
`implementation`, транзитивно в тестовый classpath `platform-api` не
протекает. Новые тесты: `AuthApiTests.rejectsSelfRegistrationAsAdmin`,
`ProviderApiTests.newProvidersStartPendingAndOnlyAnAdminCanModerateThem`
(владелец и анонимный запрос получают 403/401, админ — 200, статус
меняется, `?status=` фильтр отражает изменение),
`SearchApiTests.pendingProvidersAreInvisibleToSearchUntilAnAdminApprovesThem`
+ оба существующих search-теста теперь одобряют каждого созданного
провайдера через нового `approve()`-хелпера, иначе они бы сами сломались
об новую фильтрацию. `./gradlew build` — BUILD SUCCESSFUL, все 21
backend-тест (было 18) проходят.

### Flutter (Business Admin)
- `packages/core_network`'s `DioClient` получил `patch()` (был только
  get/post/put/delete).
- `SalonAdminApi.listProvidersByStatus()` / `.updateProviderStatus()`.
- Новый `features/moderation/` (по аналогии с `features/dashboard/`):
  `pendingProvidersProvider` (переиспользует `SalonAdminApi`, не
  отдельный API-класс — это тот же ресурс Provider, просто
  привилегированный вид) и `ModerationScreen` (список PENDING-салонов,
  кнопки Approve/Suspend, инвалидация после действия).
- `AuthGate` теперь ветвится по роли: `ADMIN` → `ModerationScreen` вместо
  `DashboardScreen` (у ADMIN нет своих салонов). PROVIDER_OWNER/CUSTOMER —
  без изменений.
- Новые тесты: `moderation_screen_test.dart` (пустое состояние, approve
  убирает салон из очереди), `auth_gate_test.dart` (ADMIN → модерация,
  PROVIDER_OWNER → dashboard, ни один экран не показывается не той роли).
  `flutter analyze` — чисто и в `business_admin`, и в `core_network`.
  `flutter test` — все 18 проходят (было 14, +4 новых: 2 в
  `moderation_screen_test.dart`, 2 в `auth_gate_test.dart`).
  `flutter build web` — собирается.

### Живая проверка
Поскольку публичная регистрация ADMIN теперь заблокирована, тестовый
ADMIN-аккаунт создан вручную через `docker exec ... psql` (bcrypt-хеш
пароля сгенерирован тем же `BCryptPasswordEncoder`, что и на бэкенде, —
через одноразовый `javac`/`java`-снаппет с зависимостями из Gradle-кеша,
не через backend). Через curl — полный контракт: владелец создаёт салон
(стартует `PENDING`) → владелец пытается сам себя одобрить → `403` →
поиск не находит салон → админ одобряет (`PATCH .../status`) → `200`,
`ACTIVE` → поиск теперь находит. Через живой браузер: залогинился в
Business Admin под ADMIN, увидел экран "Salon moderation" со списком **из
реальных накопленных за сессию PENDING-салонов** (наглядное
подтверждение, что пробел был настоящим, а не гипотетическим) — нажал
Approve на одном, салон мгновенно исчез из очереди без перезагрузки
страницы. Скриншоты отправлены пользователю.

### Статус
Реализовано и полностью проверено (backend build+test, Flutter
analyze+test+build, curl e2e, живой браузер), закоммичено и запушено
(`92a8949`).

---

## Factory Design System: артефакт, затем перевод токенов в Flutter (2026-08-21)

### Дизайн-система (артефакт)
Пользователь дал развёрнутый бриф на полную UX/UI дизайн-систему для
Beauty-вертикали, переиспользуемую под будущие вертикали ("Factory Design
System" — не Beauty-система). Собран и опубликован единый HTML-артефакт
(`https://claude.ai/code/artifact/36cdb1f3-0dfe-43fc-a64c-e9d6435dbcef`):
- **Палитра**: тёплый каменный нейтраль + primary "pine" (глубокий
  зелёный, ассоциация с Тянь-Шанем — доверие, не привязан к "розовой
  бьюти-эстетике", годится под Auto/Dental) + gold только для
  рейтинга/premium-акцентов. Dark mode — отдельные токены, не инверсия
  (primary в тёмной теме ярче — "mint", а не тот же pine).
- **Типографика**: Unbounded (заголовки) + Golos Text (UI/тело — шрифт,
  спроектированный под кириллицу+латиницу, что реально важно для
  KZ/RU-рынка) + JetBrains Mono (цены/время/дистанции, табличные цифры).
- Полная схема токенов (spacing/radius/elevation/motion/a11y), библиотека
  компонентов (`ProviderCard`, `ServiceCard`, рейтинг, бейджи, time-slot
  grid, payment tile и т.д. — названы по роли, не по "beauty"-терминам),
  IA-карты, 13 экранов user-app в виде реальных мокапов телефона (включая
  light/dark пару), 4 панели Business Admin, полная таблица-инвентарь на
  все экраны из брифа с ответом на "5 вопросов" из брифа.
Пользователь одобрил: **"да одобрено"**.

### Перевод токенов в Flutter — новый пакет `packages/core_ui`
Первый, фундаментальный шаг перевода (по плану "Handoff" из самого
артефакта: "Token set → ThemeExtension/ColorScheme, light+dark" — раньше
остального, потому что без него нельзя ничего стилизовать). Новый Flutter
пакет `packages/core_ui` (третий в `packages/`, рядом с `core_network`/
`core_storage`) содержит **только фундамент**, без библиотеки виджетов —
компоненты (кнопки/карточки/чипы и т.д.) сознательно отложены на
следующий шаг, чтобы не смешивать "может ли тема примениться" с "как
выглядит конкретный виджет" в одном непроверенном проходе.
- `FactoryColors` — `ThemeExtension<FactoryColors>` с ролями из
  артефакта (bg/surface/surfaceAlt/border/text.../primary/accent/
  success/warning/error/info), статические `FactoryColors.light` и
  `.dark` с точными hex-значениями из дизайн-системы. Доступ через
  `context.factoryColors.primary` — Flutter-овский `ColorScheme` не
  умеет в роли типа `surfaceAlt`/`primaryTint`.
- `FactoryTypography.textTheme(color)` — строит Material `TextTheme`
  через `google_fonts` (`GoogleFonts.unbounded`/`.golosText`), плюс
  отдельный `FactoryTypography.mono(...)` (`GoogleFonts.jetBrainsMono`,
  `FontFeature.tabularFigures()`) — у Material `TextTheme` нет
  моно-роли, а токен для цен/времени в артефакте был явно заявлен.
- `FactorySpacing`/`FactoryRadius`/`FactoryMotion` — простые константы
  1:1 из шкал артефакта (4pt spacing, radius 8/12/16/24, durations
  120/200/320мс + emphasized-decelerate curve).
- `factoryLightTheme()`/`factoryDarkTheme()` — собирают полноценную
  `ThemeData`: старт от `ColorScheme.fromSeed(seedColor: colors.primary)`
  (чтобы все внутренние Material3-роли типа `surfaceContainerHighest`,
  которые в токен-наборе артефакта не описаны, получили осмысленное
  значение), затем `.copyWith(...)` переопределяет ровно те роли, что
  определены в артефакте. Плюс component themes: `AppBarTheme`,
  `CardTheme` (radius lg, только hairline-бордер, elevation 0 — "avoid
  excessive shadows" из брифа), кнопки, `InputDecorationTheme`,
  `ChipTheme` (pill), `BottomSheetTheme`, `SnackBarTheme` и т.д.
- Оба приложения (`user_app`, `business_admin`) получили зависимость на
  `core_ui`; их `AppTheme.light`/`.dark` (раньше — буквально дефолтный
  Material `ColorScheme.fromSeed(seedColor: 0xFF6200EE)`, тот самый
  "сине-фиолетовый generic Flutter" вид, который бриф прямо просил
  избегать) теперь — тонкие обёртки, делегирующие в
  `factoryLightTheme()`/`factoryDarkTheme()`. `app.dart` в обоих
  приложениях не тронут — контракт `AppTheme.light`/`.dark` сохранён.

### Тесты и живая проверка
- `core_ui`: `flutter analyze` — чисто, новый `factory_theme_test.dart`
  (3 теста — палитра light отличается от дефолтного seed, dark — не
  инверсия light (другой primary), `context.factoryColors` доступен).
  **Нюанс**: `google_fonts` в тестах пытается качать шрифты по сети — в
  голом `test()` это падает необработанным исключением; обёрнуто в
  `testWidgets()`, чей биндинг терпит сетевой сбой и откатывается на
  системный шрифт, не роняя тест. Если когда-нибудь понадобится офлайн
  без сети вообще — `GoogleFonts.config.allowRuntimeFetching = false`
  требует, чтобы шрифт лежал в ассетах приложения, иначе тоже падает —
  не универсальное решение, поэтому не используется.
- `user_app` и `business_admin`: `flutter analyze` — чисто в обоих,
  `flutter test` — все проходят (18/18 admin, 30/30 user_app),
  `flutter build web` — собирается в обоих.
- **Живая проверка в браузере** — самое важное: `user_app` в dark
  режиме показывает мятно-зелёный (не пурпурный) акцент на нижней
  навигации, тёплый почти-чёрный фон (не инверсия белого). Business
  Admin: экран логина — тот же мятный `factoryLightTheme` вместо
  прежней сиреневой кнопки `ColorScheme.fromSeed(0xFF6200EE)`.
  Скриншоты подтверждают: тема реально применилась в обоих приложениях,
  не только компилируется. Столкнулся с известной автоматизационной
  проблемой (см. также прошлые разделы этого файла): `SetForegroundWindow`
  из свежего PowerShell-процесса тихо не срабатывал, пока фокусное окно
  явно не свёрнуто (`ShowWindow(..., 6)`) — иначе скриншот ловил
  предыдущее окно поверх нужного.

### Статус
`core_ui` (только фундамент — токены/тема, без компонентной библиотеки)
реализован, оба приложения переключены на него, всё протестировано и
проверено вживую, закоммичено и запушено (`633d6be`).

## Компонентная библиотека `core_ui` (2026-08-21, продолжение)

Пользователь сказал "продолжай" — второй шаг перевода дизайн-системы:
переиспользуемые виджеты поверх токенов/темы из прошлого шага. Всё ещё
только `core_ui` — применение к реальным экранам осознанно отложено на
следующий шаг (не смешивать "виджет корректен сам по себе" с "виджет
корректно встроен в конкретный экран" в одном непроверенном проходе).

Новые виджеты (`packages/core_ui/lib/src/widgets/`), все на токенах
(`FactoryColors`/`FactoryTypography`/`FactorySpacing`/`FactoryRadius`/
`FactoryMotion`, ни одного захардкоженного числа):
- `FactoryAvatar` — круглый аватар с инициалами, опционально с реальным
  фото (`ImageProvider`).
- `FactoryBadge` — `verified`/`available`/`limited`/`neutral`, цвет
  определяется вариантом, не текстом — то самое "Verified booking" как
  сквозной trust-сигнал из брифа.
- `FactoryRatingLabel` — звезда + рейтинг + счётчик отзывов, с
  `Semantics`-лейблом "4.9 out of 5, 212 reviews" целиком (не просто
  цифры и иконка) — пункт "screen readers" из раздела accessibility
  артефакта.
- `FactoryPriceText` + `formatFactoryAmount()` — группировка тысяч
  пробелом (12400 → "12 400"), сумма всегда в `FactoryTypography.mono`
  (JetBrains Mono), необязательный `prefix` ("from ") в обычном теле.
  Сознательно без пакета `intl` — одно строковое правило не стоит новой
  зависимости; если понадобится локаль-зависимое форматирование, менять
  только эту функцию.
- `FactoryChip` — пилюля-фильтр как обычный `GestureDetector`, не
  `ChoiceChip`: у Material-чипа свои опции по размеру/ripple, которые
  спорили с компактными пропорциями артефакта.
- `ProviderCard` — флагманский компонент. `ProviderCardLayout.vertical`
  (картинка сверху, для горизонтальных discovery-рядов) и `.horizontal`
  (картинка слева, для списка результатов поиска) — оба варианта из
  артефакта. Не знает, как грузить картинку — `image` передаёт вызывающий
  код, чтобы `core_ui` не тянул зависимость на конкретный image-loader.
  Название без слова "Beauty"/"Salon" — по роли, не по вертикали.
- `ServiceRow` — строка услуги (название+мета слева, цена справа).
- `FactoryTimeSlot` — `available`/`selected`/`unavailable`; недоступность
  никогда не только цветом — зачёркнутый текст + отключённый tap, не
  только приглушённая рамка (dashed border не делал — у Flutter нет
  штатной поддержки пунктирной рамки без кастомного painter, сочли
  избыточным ради второстепенной детали).
- `FactoryEmptyState` / `FactoryErrorState` — пустое состояние (иконка +
  заголовок + сообщение + необязательный CTA) и состояние ошибки
  (понятное сообщение + Retry) — реализуют явное правило брифа "не
  показывать техническую ошибку бэкенда".
- `FactorySkeleton` — шиммер-плейсхолдер; уважает `prefers-reduced-motion`
  через `MediaQuery.disableAnimationsOf` — рендерит статичный блок вместо
  анимации, когда ОС просит меньше движения.

### Ошибки, найденные тестами (не архитектурные, но реальные)
- `FactoryPriceText` изначально был на `RichText`+`TextSpan` — тесты
  `find.text(...)` не находили ни `prefix`, ни сумму по отдельности
  (сплошной `toPlainText()` не совпадал ни с одной проверяемой строкой).
  Переписан на `Row` из двух `Text` — и корректнее по коду, и
  предсказуемо тестируется; `ServiceRow` унаследовал исправление
  бесплатно, так как использует `FactoryPriceText` внутри.
- `FactorySkeleton`-тест на reduce-motion: `MediaQuery`, поставленный
  **над** `MaterialApp`, не доходит до виджета — `MaterialApp` строит
  свой `MediaQuery` от текущего `View` и перекрывает внешний. Тест
  пришлось переставить — `MediaQuery` должен быть **внутри** дерева
  `MaterialApp`, не снаружи. Стоит помнить для любых будущих тестов на
  `MediaQuery`-зависимое поведение.
- Тест на `AnimatedBuilder` для reduce-motion сначала проверял "нигде в
  дереве нет `AnimatedBuilder`" — ловил чужой `AnimatedBuilder` из
  внутренностей `MaterialApp`/`Scaffold`, не имеющий отношения к
  `FactorySkeleton`. Исправлено на `find.descendant(of: FactorySkeleton,
  matching: AnimatedBuilder)` — только в поддереве самого виджета.
- Deprecated API в тесте: `SemanticsData.hasFlag()` устарел в пользу
  `flagsCollection` (новый API для флагов — не битовая маска, а
  `Tristate`-поля); заменено на
  `semantics.flagsCollection.isSelected.toBoolOrNull()`.

### Проверка
`flutter analyze` — чисто (`core_ui`, оба приложения — виджеты пока
нигде не подключены, но пакет не сломал существующую сборку). Новый
`test/factory_widgets_test.dart` — 15 тестов (формат цены, семантика
рейтинга/чипов/time-slot, избранное в `ProviderCard`, tap-коллбэки,
условный CTA в empty-state, static-режим skeleton при reduce-motion).
Итог по `core_ui`: 18/18 (3 из прошлого шага + 15 новых).

### Статус
Компонентная библиотека реализована и протестирована, закоммичена и
запушена (`b9cc0c1`).

## Home и Search в user_app (2026-08-20)

Пользователь: "Начни с Home и Search в user_app". Первое применение
дизайн-системы к реальным экранам — не просто рестайлинг, а закрытие
реального разрыва: утверждённая IA описывает 5 табов (Home/Search/
Bookings/Favorites/Profile), а в коде были только 3 (Home/Settings/
Profile), и Search вообще не существовал отдельно — весь поиск был
слит в один `DiscoveryScreen`. Bookings/Favorites как табы — осознанно
не тронуты в этом шаге (отдельное решение, не часть "Home и Search").

### Что сделано
- `DiscoveryScreen` удалён, вместо него два экрана:
  `HomeScreen` (локация-пилюля "Almaty" — тот же fixed mock-origin, что
  и у maps-фичи; tap-only поле поиска, переключающее на таб Search через
  `context.go('/search')`, а не push; hero-баннер "N salons... open
  slots today" — честный count из уже загруженных результатов, не
  отдельный backend-запрос; горизontal ряд `ProviderCard` "Top rated
  near you") и `SearchScreen` (реальное поле ввода, вертикальный список
  результатов, `FactoryEmptyState`/`FactoryErrorState`).
- `app_router.dart`/`main_wrapper.dart` — добавлен `/search` как новая
  ветка `StatefulShellRoute` + таб "Search" в `NavigationBar` (теперь
  4 таба: Home/Search/Settings/Profile).
- Локальный `discovery/presentation/widgets/provider_card.dart`
  переписан в тонкий адаптер: маппит `ProviderSearchResult` (бэкенд не
  отдаёт `rating` — сознательно не выдумано) на поля `core_ui.ProviderCard`
  (`metaText` = дистанция+вертикаль, `availabilityLabel` из
  `hasOpenAvailability`). Публичный конструктор не менялся, поэтому
  `FavoritesScreen` (тоже использует этот `ProviderCard`) получил новый
  вид бесплатно, без своих правок.
- Импорт `core_ui` в экранах — `hide ProviderCard`, так как и в
  `core_ui`, и локально есть класс с таким именем (конфликт имён,
  ожидаемый и решённый через `as`/`hide`, не баг).

### Реальный баг, найденный тестами (не рефлексия, а падение layout)
Первый прогон тестов на `HomeScreen` (карточка `width: 168` в
горизонтальном ряду) уронил `core_ui.ProviderCard` с overflow —
и `FactoryPriceText`, и `FactoryBadge` были на `Row(mainAxisSize: min)`
без защиты от нехватки места, а длинная надпись "Available today" рядом
с ценой в узкой карточке в это не помещалась. Три исправления в
`core_ui` (не только в `user_app`):
1. Футер `ProviderCard` (цена + бейдж) — `Row` → `Wrap`, переносится на
   вторую строку вместо падения.
2. `FactoryPriceText` и `FactoryBadge` — обёрнуты в
   `FittedBox(fit: BoxFit.scaleDown)`: если контента больше, чем места,
   он аккуратно уменьшается, а не роняет layout. Общий паттерн для
   любого текста непредсказуемой длины (цена/статус), не разовый патч.
   Новый регрессионный тест в `core_ui` (`factory_widgets_test.dart`) —
   узкая карточка 168px с ценой и длинным бейджем не должна ронять
   `RenderFlex`.
- `HomeScreen`: высота `SizedBox` под горизонтальный ряд карточек
  увеличена 192 → 220 (с комментарием — почему), чтобы хватало места
  под возможный перенос футера на 2 строки.

### Тесты
Новые `home_screen_test.dart` (3 теста) и `search_screen_test.dart`
(3 теста). Обновлён `favorites_screen_test.dart` — ассерт на текст
"Haircut" убран (старый локальный `ProviderCard` показывал chip-список
услуг, `core_ui.ProviderCard` этого не делает — сознательное упрощение
компонента, не баг). Все Material-тесты, что рендерят `ProviderCard`
(discovery x2, favorites), теперь оборачивают `MaterialApp` в
`theme: factoryLightTheme()` — без этого `context.factoryColors`
падает с null-check (тема не по умолчанию, её нужно явно задать в
тесте, как и в `core_ui`'s собственных тестах). `flutter analyze` —
чисто и в `core_ui`, и в `user_app`. `flutter test`: `core_ui` 19/19
(было 18, +1 регрессионный), `user_app` 34/34. `flutter build web` —
собирается.

### Живая проверка в браузере
Засеял 3 реальных ACTIVE-провайдера через curl (админ создан вручную в
БД, как и раньше — `/auth/register` блокирует ADMIN) с разной ценой/
дистанцией/наличием слотов. **Home (dark-режим системы)**: локация,
tap-поиск, тёплый teal hero-баннер "2 salons... open slots today",
5 карточек в ряд, у карточек со слотами — бейдж "Available today", у
остальных — корректно без бейджа, нет overflow. **Search (light-режим
— оба варианта темы подтверждены живьём)**: список из тех же
провайдеров вертикально, цена в моно-шрифте, бейдж на своих местах.
Экран логина (не трогали в этом шаге) тоже уже на Factory-теме —
подтверждает, что тема применяется сквозь всё приложение, не только к
новым экранам.

**Побочный инцидент при автоматизации скриншотов** (не связано с
кодом): при первой попытке скрин попал не в то Chrome-окно и захватил
личный WhatsApp Web пользователя (переписки, фото) — известная на этой
машине проблема `SetForegroundWindow`, тихо не срабатывающего без
предварительного сворачивания текущего активного окна. Файл удалён
немедленно, содержимое нигде не сохранялось и не анализировалось,
проблема исправлена (сворачивать текущее активное окно перед
переключением) и повторный скрин получен уже корректно из нужного окна.

### Статус
Реализовано, протестировано (unit + живой браузер, обе темы),
закоммичено и запушено (`286c848`).

## Рабочий логотип (2026-08-21)

Пользователь попросил сначала логотип, отдельно от экранов. Не финальный
бренд — "Factory" остаётся кодовым названием, стандартное правило не
нарушено. Три концепции построены только на уже существующих токенах
`core_ui` (primary/primary-strong/accent/border-strong — ничего нового
в палитру не добавлено): рекомендованный **Module Mark** (сетка 2×2 —
три закрашенных модуля, один из них золотой = первая живая вертикаль
Beauty, четвёртый нарисован пунктиром = осознанно незаполненный слот под
следующую вертикаль — структура несёт смысл, а не декоративна) плюс два
альтернативных варианта (Interlock Mark, Layered Mark) для сравнения.
Артефакт включает проверку читаемости на размерах 96/48/32/16px и
мокап как app-иконка для обоих Flutter-приложений. Опубликовано:
https://claude.ai/code/artifact/572dd1ce-a45f-4661-a105-6ed702e4c4c7.
Файлы (SVG/иконки) в репозиторий пока не добавлены — только визуальный
концепт на утверждение.

## ProviderDetailScreen на дизайн-системе Factory (2026-08-21)

Второй реальный экран после Home/Search. Экран уже был функционально
полным (выбор мастера/услуги/слота, бронирование, оплата) — задача была
чисто визуальная: убрать `RadioListTile`/`ChoiceChip` (обычный Material,
не в стиле Factory) и собрать экран из компонентов `core_ui`.

### Что сделано
- Хедер: `FactoryBadge` для вертикали (нейтральный) и "Available today"
  (зелёный), дистанция в моно-шрифте — вместо голого `Text`.
- Мастера: убран `RadioGroup`/`RadioListTile`, вместо них новый
  приватный `_MasterOption` — карточка с `FactoryAvatar` (инициалы как
  fallback, если нет `photoUrl`), рамка+тинт+галочка при выборе (тот же
  паттерн, что у `FactoryTimeSlot`), кнопка портфолио без двойной рамки
  (локальный `IconButton.styleFrom` поверх глобальной темы, чтобы не
  плодить рамку в рамке).
- Услуги: `ServiceRow` теперь умеет `selected` (новый параметр в
  `core_ui`) — рамка+тинт+галочка вместо неотличимого выделения, с тем
  же `Semantics(selected: ...)`, что и у `FactoryTimeSlot`/`FactoryChip`.
  Первое реальное использование `ServiceRow` в приложении — раньше он
  существовал только в тестах `core_ui`.
- Время: `ChoiceChip` заменён на `FactoryTimeSlot`.
- Пустое состояние "нет слотов": `FactoryEmptyState` вместо голого
  текста.

### Два реальных гэпа в core_ui, найденных этим экраном
1. **`FactoryTimeSlot` был без горизонтального паддинга** (только
   vertical) — для коротких меток вроде "18:00" незаметно, но для
   реальной метки этого экрана ("Jan 1, 10:00", т.к. слот не привязан к
   конкретному дню в UI) текст вплотную упирался в рамку. Добавлен
   `horizontal: 10`.
2. **`FilledButton` не был затемплейчен** — тема определяла
   `elevatedButtonTheme`, но не `filledButtonTheme`, хотя кнопка Book на
   этом экране всегда была `FilledButton`. Без темы она получала
   Material3-дефолтную форму (не `mdRadius`), просто раньше это было
   незаметно, пока рядом не оказались другие Factory-кнопки для
   сравнения. Добавлен `filledButtonTheme` в `factory_theme.dart`,
   зеркальный `elevatedButtonTheme`.

### Тесты
`provider_detail_screen_test.dart` обновлён: добавлен
`theme: factoryLightTheme()` в оба `MaterialApp` (тот же гэпч, что и в
прошлых шагах — четвёртый раз за проект), ассерт про "No open time
slots right now." заменён на "No open times" (текст `FactoryEmptyState`).
Логика тестов (выбор услуги/слота/мастера, включение кнопки Book,
данные, которые уходят в бронирование) не менялась — она и так была
устойчива к визуальному рефакторингу, раз находит элементы по тексту.
Новый regression-тест в `core_ui` на `ServiceRow(selected: true)`.
`core_ui` 20/20 (было 19, +1), `user_app` 34/34, `flutter analyze` чисто
в обоих пакетах, `flutter build web` собирается.

### Живая проверка в браузере
Досеял в Postgres (напрямую, в обход API — так же, как раньше сеялся
ADMIN) двух мастеров для Aigerim Beauty Studio (с био и без — проверить
оба варианта карточки) и привязал их к услуге Haircut, чтобы увидеть
секцию "Masters" вживую (в БД её раньше не было ни у одного из ранее
засеянных провайдеров). Подтверждено вживую: карточки мастеров с
инициалами-аватаром; выбор мастера/услуги/слота по одному — каждый
получает рамку+тинт+галочку (мастер и услуга) или тёмную заливку (слот);
кнопка Book корректно переходит из приглушённого disabled-состояния в
полностью тёмно-зелёный enabled после того, как выбраны все три вещи
(услуга+слот+мастер, т.к. у этого провайдера есть мастера). Отдельно
проверен провайдер без мастеров и без слотов (Nail Bar 21) — секция
Masters корректно не рендерится вообще, вместо списка времени —
`FactoryEmptyState` "No open times / Check back later or try another
provider.", кнопка Book остаётся disabled.

**Заметка про автоматизацию скриншотов**: в этой сессии посторонний
процесс на машине (не Chrome) периодически перехватывал фокус между
отдельными вызовами PowerShell — та же категория проблемы, что и раньше
(`SetForegroundWindow` не держит фокус), но в этот раз агрессивнее.
Дважды сработала защита "проверить PID переднего плана прямо перед
сохранением скриншота" — оба раза найден чужой фокус, оба раза файл
не сохранён/удалён без просмотра. Рабочим решением оказалось: (1) один
Alt-tap через `keybd_event` перед каждым `SetForegroundWindow`, чтобы
сбросить Windows foreground-lock; (2) не использовать `SetCursorPos`
для кликов — на этой машине он давал непредсказуемое DPI-масштабирование
координат (клик по видимой на скриншоте точке не туда попадал); вместо
этого — `mouse_event` с `MOUSEEVENTF_ABSOLUTE` и координатами,
нормализованными в 0..65535 через `GetSystemMetrics`, что и оказалось
надёжным. Стоит переиспользовать эту связку в следующих шагах вместо
прежнего `SetCursorPos`-подхода.

### Статус
Реализовано и проверено (unit-тесты + живой браузер, оба сценария — с
мастерами и без), закоммичено и запушено (`77d7bef`).

## Bookings и Favorites на дизайн-системе Factory (2026-08-21)

Пользователь: "Давай Bookings и Favorites в user_app". `FavoritesScreen`
уже частично была на дизайн-системе (использует локальный `ProviderCard`,
который сам оборачивает `core_ui.ProviderCard` ещё с шага Home/Search) —
её правки минимальны. `MyBookingsScreen` не трогали ни разу — полный
редизайн.

### Что сделано
- `MyBookingsScreen`: пустое состояние → `FactoryEmptyState`, ошибка →
  `FactoryErrorState` с retry, карточка бронирования — `FactoryPriceText`
  вместо ручного `'\$...'`, статус — `FactoryBadge` (CONFIRMED → зелёный
  `available`, COMPLETED → `verified`, CANCELLED → новый `error`-вариант,
  остальное → `neutral`), дата отформатирована человеко-читаемо (было
  сырое `DateTime.toString()`).
- `FavoritesScreen`: пустое/ошибочное состояние на `FactoryEmptyState`/
  `FactoryErrorState`, `ListView.builder` → `ListView.separated` с
  прогалами `FactorySpacing.space3` между карточками (раньше карточки
  визуально слипались).
- `PaymentStatusChip`: обычный Material `Chip` с хардкодным
  `Colors.green`/`Colors.red` → `FactoryBadge` (SUCCEEDED → `available`,
  FAILED → новый `error`-вариант, остальное → `neutral`), лейбл
  капитализирован ("Payment: Succeeded", не "Payment: SUCCEEDED").
- `ReviewSection` (звёзды и в выведенном отзыве, и в диалоге выбора
  оценки): `Colors.amber` → `context.factoryColors.accent` — это как раз
  тот golden-accent, который дизайн-система резервирует именно под
  рейтинги.

### Новый вариант в core_ui
`FactoryBadgeVariant` получил `.error` (красный, тот же паттерн alpha-blend,
что у `.warning`/`.limited`) — реальная потребность: до этого шага не было
ни одного места в приложении с отменённым бронированием или упавшим
платежом, поэтому гэп не был виден. Новый regression-тест в
`factory_widgets_test.dart`.

### Тесты
`theme: factoryLightTheme()` добавлен в `my_bookings_screen_test.dart`,
`payment_status_chip_test.dart`, `review_section_test.dart` (пятый и
шестой раз этот же гэпч — уже устоявшийся ритуал при любом касании
core_ui). Обновлены текстовые ассерты под новый вид: цена
(`'\$42.50'` → `'43 ₸'`, т.к. `FactoryPriceText` всегда в тенге с
округлением, тот же приём, что и на предыдущих экранах), статус
(`'CONFIRMED'` → `'Confirmed'`), лейбл платежа (`'Payment: SUCCEEDED'` →
`'Payment: Succeeded'`), пустые состояния (убраны точки в конце текста,
единый стиль с прошлыми шагами). `core_ui` 21/21 (было 20, +1),
`user_app` 34/34 (то же число тестов, поменялся только их контент),
`flutter analyze` чисто в обоих пакетах, `flutter build web` собирается.

### Живая проверка в браузере
Досеял через API (обычный auth + curl, без прямых SQL-вставок, кроме
самого статуса CANCELLED — для него в бэкенде вообще нет endpoint'а,
статус выставлен напрямую в БД) три бронирования одному тестовому
покупателю: CONFIRMED с оплатой, COMPLETED с оплатой и реальным отзывом
(5 звёзд + комментарий), CANCELLED без ничего — и два избранных
провайдера. Зашёл в приложение (тёмная тема на этот раз — хорошая
попутная проверка обеих тем на реальных данных), залогинился через форму
логина вручную (email/пароль через `SendKeys`), открыл My bookings —
все три карточки отрендерились корректно, включая три разных цвета
бейджа статуса и полный блок отзыва на завершённой записи; открыл My
favorites — две карточки, "Available today" только там, где реально
есть открытый слот. Никаких overflow, всё читаемо в тёмной теме.

**Ещё один живой баг найден в процессе, не в коде — в автоматизации**:
Chrome сам показал нативный попап "Сохранить пароль?" после логина,
перекрывший экран; клик по расчётным координатам "Нет, спасибо" не
попал (кнопки браузерного попапа не всегда совпадают с ожидаемыми
координатами — это UI браузера, не наш code), Escape тоже не сработал;
помогло только точное попадание по крестику закрытия попапа. Не влияет
на код проекта, но стоит держать в голове при следующей живой проверке
через форму логина: браузер может показать этот попап и его придётся
закрывать явным кликом по X.

### Статус
Реализовано и проверено (unit-тесты + живой браузер, обе темы, все
статусы бронирования и оплаты), закоммичено и запушено (`7c0c4dc`).

## SalonDetailScreen и DashboardScreen в Business Admin (2026-08-21)

Пользователь: "Давай Business Admin — SalonDetailScreen и DashboardScreen".
Business Admin уже был подключён к `core_ui` (тема применяется глобально
через `AppTheme.light/.dark` → `factoryLightTheme()/factoryDarkTheme()`),
но сами экраны ещё не использовали компоненты дизайн-системы — обычные
`ListTile`/`Card`/голый текст. Диалоги (`AddServiceDialog`,
`AddSlotDialog`, `AddMasterDialog` и т.д.) трогать не пришлось вообще —
`AlertDialog`/`TextField`/`FilledButton`/`TextButton` уже полностью
наследуют тему из `factory_theme.dart` (то же самое наблюдение, что уже
не раз подтверждалось в этой сессии: раз глобальная тема на месте,
новый код бесплатно её получает).

### DashboardScreen
Список салонов: `Card(ListTile(...))` → карточка `_SalonCard`
(название + вертикаль текстом + `FactoryBadge` статуса + шеврон),
`ListView.builder` → `ListView.separated` с прогалами
`FactorySpacing.space3`. Статус провайдера (`ProviderStatus`:
PENDING/ACTIVE/SUSPENDED) впервые получил цветовую кодировку:
ACTIVE → зелёный `available`, PENDING → жёлтый `limited` ("не готово
до конца"), SUSPENDED → красный `error`. Пустой список (нет салонов) —
форма создания салона осталась своей (`_CreateSalonForm`, не
`FactoryEmptyState`, т.к. у неё есть реальное поле ввода, а не просто
кнопка-действие), но её иконка-кружок теперь оформлена в том же
визуальном языке, что и `FactoryEmptyState` (52px круг, `surfaceAlt`).
Ошибка загрузки → `FactoryErrorState` с retry.

### SalonDetailScreen
Самый большой экран проекта на данный момент — 4 секции (Services,
Availability, Masters, Bookings), каждая со своими CRUD-действиями.
Хедер: было `Text('beauty — ACTIVE')` одной строкой → два отдельных
`FactoryBadge` (вертикаль нейтральным цветом + статус тем же
цветокодированием, что и на Dashboard).
- **Услуги**: `ListTile` → новый `_ServiceAdminRow` (цена через
  `FactoryPriceText`, статус "removed" — `FactoryBadge` вместо серого
  текста впристык к названию), edit/delete иконки как были.
- **Слоты**: остались `Chip` — тема `chipTheme` уже полностью покрывает
  их бесплатно (граница, фон, форма), править нечего; единственное
  реальное улучшение — суффикс статуса в лейбле показывается только для
  не-OPEN слотов ("Aug 21, 02:47 · Booked"), а не всегда ("... — OPEN"
  для самого частого случая было лишним шумом).
- **Мастера**: `Card(ListTile(...))` → `_MasterAdminRow`, тот же
  визуальный паттерн, что и `_MasterOption` в `user_app`'s
  `ProviderDetailScreen` (`FactoryAvatar` с инициалами, рамка+статус),
  независимая копия (эти два приложения не шарят код, только `core_ui`).
- **Бронирования**: `ListTile` с одной строкой `'\$25.00 — CONFIRMED'`
  → `FactoryPriceText` + `FactoryBadge` статуса (та же цветовая схема,
  что и в `user_app`'s `MyBookingsScreen`: CONFIRMED зелёный, COMPLETED
  бирюзовый `verified`, CANCELLED красный).

### Тесты
`theme: factoryLightTheme()` добавлен в `auth_gate_test.dart` (там, где
логинится PROVIDER_OWNER и рендерится DashboardScreen),
`dashboard_screen_test.dart`, `salon_detail_screen_test.dart` — восьмой
и девятый раз этот же гэпч встречается в проекте, уже совсем рутина.
Обновлены ассерты, которые реально сломались от смены визуального
представления: `'beauty — ACTIVE'` → отдельно `'Beauty'` и `'Active'`;
`'\$25.00 — COMPLETED'` → отдельно `'25 ₸'` и `'Completed'`. Все
остальные ассерты (тултипы 'Edit'/'Edit salon', тексты 'Add'/'Show
removed'/'Reactivate'/'Mark complete', `find.byType(Chip)`,
`find.byIcon(Icons.delete_outline)`) не потребовали изменений — они
были завязаны на функциональные хуки, а не на конкретную вёрстку,
редизайн их не задел. `business_admin`: 18/18 тестов (столько же,
сколько было, поменялось только их содержимое), `flutter analyze`
чисто, `flutter build web` собирается.

### Живая проверка в браузере
Засеял нового владельца через `/auth/register` + два салона через
`POST /providers` (оба ушли в PENDING — сразу живая проверка жёлтого
`limited`-бейджа, которого раньше никто не видел вживую). Один салон
(Velvet Studio) заполнил полным набором данных: 2 услуги (1 активная,
1 удалённая), 2 слота (оба забронированы — проверка суффикса "· Booked"
в чипе), 2 мастера (1 активный с био, 1 удалённый), 2 бронирования
(CONFIRMED и COMPLETED, через реального клиента и `/complete`).
Залогинился в Business Admin как этот владелец (тёмная тема) — Dashboard
показал обе карточки с жёлтыми "Pending" бейджами; открыл Velvet Studio
— все 4 секции отрендерились корректно: услуги с ценой в тенге, слоты
без иконки удаления (раз не OPEN), мастер с аватаром-инициалами и тремя
иконками действий, бронирования с правильными цветными бейджами и
кнопкой "Mark complete" только у CONFIRMED. Переключил "Show removed" у
обеих секций (услуги и мастера) — скрытые записи появились серым текстом
с бейджем "Removed" и кнопкой "Reactivate", как задумано. Ни одного
overflow нигде. Столкнулся с уже знакомым попапом Chrome "Сохранить
пароль?" — закрыт тем же способом (клик по крестику), что и в прошлый
раз.

### Статус
Реализовано и проверено (unit-тесты + живой браузер, все 4 секции,
все состояния активности/бронирования), закоммичено и запушено
(`a66ffb3`).

## ModerationScreen в Business Admin (2026-08-21)

Пользователь: "Давай ModerationScreen тоже" — последний нетронутый
экран, закрывающий дизайн-систему полностью в обоих приложениях.
Небольшой экран, правки точечные:
- Список: `Card(ListTile(...))` → карточка `_PendingSalonCard`
  (название + `FactoryBadge` вертикали нейтральным цветом вместо голого
  `Text(p.vertical)`), `ListView` → `ListView.separated` с прогалами
  `FactorySpacing.space3`. Suspend/Approve кнопки не трогал — `TextButton`/
  `FilledButton` уже полностью из глобальной темы.
- Пустое состояние ("нет салонов на модерации") → `FactoryEmptyState`.
- Ошибка загрузки → `FactoryErrorState` с retry (раньше отсутствовала
  вообще — голый `Text('Failed to load pending salons: $error')`, теперь
  как везде в проекте).

### Тесты
`theme: factoryLightTheme()` добавлен в `moderation_screen_test.dart`
(десятый раз этот же гэпч в проекте). Единственная реально сломанная
строка — вертикаль теперь капитализирована (`'beauty'` → `'Beauty'`,
тот же приём, что и на Dashboard/SalonDetailScreen); текст пустого
состояния убрал точку в конце (`'No salons awaiting approval.'` →
`'No salons awaiting approval'`), консистентно с остальным проектом.
2/2 теста, `flutter analyze` чисто, `business_admin` 18/18 в сумме.

### Живая проверка в браузере
Понадобился реальный ADMIN — новый, через прямую вставку в БД
(`app_user`+`credential`, bcrypt-хеш тем же трюком с `HashGen.java`/
`javac`/`java` из прошлых шагов, переиспользован скомпилированный класс
из scratchpad). В базе уже накопилось 25 подвисших PENDING-салонов за
всю историю ручного тестирования этого проекта — отличный, совершенно
не постановочный набор данных для проверки длинного списка. Залогинился
как admin — экран показал все 25 карточек корректно (имя, "Beauty"
бейдж, кнопки), без единого overflow при прокрутке. Нажал "Approve" на
одной карточке — она мгновенно пропала из списка (реальный API-вызов
`PATCH .../status`, инвалидация провайдера), список пересчитался без
перезагрузки страницы.

### Статус
Реализовано и проверено (unit-тесты + живой браузер, полный список +
approve), закоммичено и запушено (`8453b6a`).

## Локализация: kk/ru/en в user_app (2026-08-21)

Пользователь объяснил стратегию выхода на рынки: старт в Казахстане
(поэтому обязателен казахский), с прицелом легко добавлять новые страны
позже (Узбекистан, Кыргызстан, Турция, Россия, США, Европа, возможно
Китай) — то есть архитектура локализации должна быть готова принять
любой следующий язык почти без трения. Это отдельная от дизайн-системы
задача — начал с `user_app` (клиентское приложение, для конечного
пользователя язык критичнее, чем для владельца салона в админке).
`business_admin` — сознательно отдельный следующий шаг, не в этом
проходе.

### Технический выбор
Официальный Flutter-путь: `flutter_localizations` + `intl` + ARB-файлы
+ кодогенерация через `flutter gen-l10n` (настройка — `l10n.yaml`,
`generate: true` в `pubspec.yaml`). Не стал городить свой велосипед —
это ровно та задача, для которой Flutter даёт первоклассный
инструмент, а самодельное решение хуже проверено. Ключевая находка:
в установленной версии Flutter `flutter gen-l10n` по умолчанию
генерирует `.dart`-файлы прямо в `lib/l10n/` (не в synthetic package
внутри `.dart_tool`), и делает это автоматически при `flutter pub get`
(проверено: удалил сгенерированные файлы, `pub get` — вернулись сами).
Значит источник истины — только `.arb`-файлы; сгенерированные
`app_localizations*.dart` добавлены в `.gitignore` `user_app` (правило
`lib/l10n/app_localizations*.dart`), а `.arb` — в репозитории.

### Архитектура (готова к добавлению языков без переделки)
- `apps/user_app/lib/l10n/app_en.arb` (шаблон, с `@`-описаниями для
  переводчиков) + `app_ru.arb` + `app_kk.arb`. Добавить, скажем,
  узбекский или турецкий позже — это буквально один новый `.arb`-файл
  с теми же ключами, ничего в коде менять не нужно (`AppLocalizations
  .supportedLocales` собирается автоматически из набора файлов).
- `LocaleController` (`apps/user_app/lib/app/locale/locale_controller.dart`,
  `AsyncNotifierProvider<LocaleController, Locale?>`) — `null` означает
  "как в системе". Хранится через уже существующий `SecureStorageService`
  (тот же, что и auth-токены) под ключом `locale_code` — не стал
  добавлять `shared_preferences` как новую зависимость только ради
  одной некритичной настройки, раз подходящее хранилище уже подключено
  в приложении.
- `app.dart`: `MaterialApp.router` получил `locale:
  ref.watch(localeControllerProvider).value`,
  `supportedLocales`/`localizationsDelegates` из сгенерированного
  `AppLocalizations`. Когда `locale` равен `null` (нет сохранённого
  выбора), Flutter сам резолвит из локали устройства/браузера, с
  откатом на первый язык в `supportedLocales` (это `en`, порядок
  задаётся алфавитным порядком имён `.arb`-файлов) — то есть
  пользователь из страны, для которой перевода ещё нет, автоматически
  получает английский, а не случайный выбор. Ручной выбор в Settings
  всегда имеет приоритет над автоопределением.
- `SettingsScreen` (`apps/user_app/lib/features/settings/presentation/screens/settings_screen.dart`,
  переписан): секция "Язык"/"Language"/"Тіл" с диалогом-пикером.
  Важное решение: сами названия языков в пикере ("English", "Русский",
  "Қазақша") — НЕ переводятся под текущий активный язык (стандартная
  UX-конвенция для language picker — каждый язык называет себя сам, на
  своём алфавите), в отличие от остального текста экрана, который идёт
  через ARB. Заодно перевёл и вечно английские "Current theme: {mode}"/
  "System/Light/Dark" — раз уж экран трогал.
- `MainWrapper`: 4 лейбла нижней навигации (`Home`/`Search`/`Settings`/
  `Profile`) — тоже через `AppLocalizations`, это самый заметный текст
  в приложении (виден на каждом экране).

### Тесты
Новый `test/features/settings/settings_screen_test.dart` (2 теста):
дефолт "как в системе" + переключение на казахский с проверкой, что
меняется весь виджет-дерево (не только подпись в самом Settings, а
и заголовок AppBar), плюс что `SecureStorageService` реально получил
запись; второй тест — выбор "как в системе" корректно удаляет
сохранённое переопределение. Тестовый харнес (`_TestApp`) специально
зеркалит ровно то же связывание `localeControllerProvider` → `MaterialApp
.locale`, что и настоящий `app.dart` — иначе тест проверял бы только
сам пикер, а не то, что переключение реально перерисовывает приложение.
`flutter analyze` чисто, `user_app` 36/36 (было 34, +2), `flutter build
web` собирается.

### Живая проверка в браузере
Без бэкенда (не нужен для этой проверки — Settings ни к чему не
обращается). Открыл вкладку Settings — приложение **само** определило
русскую локаль браузера/ОС этой машины и отрендерилось на русском без
единого ручного действия ("Настройки", "Тёмная тема", нижняя навигация
"Главная"/"Поиск"/"Настройки"/"Профиль") — живое подтверждение, что
автоопределение реально работает, а не просто компилируется. Открыл
пикер языка — все 4 варианта на месте, галочка на "Как в системе".
Выбрал "Қазақша" — всё приложение мгновенно перерисовалось на казахском
("Баптаулар", "Қараңғы режим", "Ағымдағы тақырып: Жүйелік", "Тіл",
нижняя навигация "Басты бет"/"Іздеу"/"Баптаулар"/"Профиль") — специфичные
казахские буквы (Қ, Ғ и т.д.) отрендерились без "квадратиков", шрифт
Golos Text (выбранный ещё на этапе дизайн-системы именно из-за
поддержки кириллицы) справляется и с казахским алфавитом. Перезагрузил
страницу (F5, полный релоад) — выбор казахского пережил перезагрузку,
подтверждает, что персистентность через `SecureStorageService` реально
работает в вебе (не только in-memory на время сессии).

### Статус
Реализовано и проверено (unit-тесты + живой браузер: автоопределение,
ручное переключение, персистентность после reload), но **не
закоммичено** — ждём подтверждения.

## Следующий шаг — рекомендация архитектора
Инфраструктура локализации готова и доказана на первом срезе (нижняя
навигация + Settings). Дальше — распространить `AppLocalizations` на
остальные ~15 экранов `user_app` (Home, Search, ProviderDetailScreen,
Bookings, Favorites, Profile/Login и т.д.), по экрану-два за раз с
проверкой каждого — тем же ритмом, что и рескин на дизайн-систему.
Отдельно: та же инфраструктура нужна и в `business_admin` (свои
ARB-файлы — содержание экранов совсем не пересекается с `user_app`, так
что общий пакет локализации не нужен, как и с дизайн-системой каждое
приложение получает собственный набор строк). Также стоит явно
отметить: переводы на казахский в этом шаге — мой первый черновой
перевод, не вычитанный носителем языка; для реального запуска в
Казахстане обязательна вычитка носителем перед продакшеном.
