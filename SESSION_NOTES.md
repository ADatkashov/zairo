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
Всё застейджено, **не закоммичено** — ждём подтверждения.

## Следующий шаг — рекомендация архитектора
**Phase 4 (Beauty vertical) закрыта.** Второй vertical (Auto, Phase 9 по
roadmap) — хороший момент проверить KPI проекта ("насколько быстрее
собирается второй vertical благодаря сделанному разделению Core/Vertical"),
но ADR-0003 отмечает, что пересматривать multi-tenant/изоляцию рано, пока
нет второго реального клиента. Дальше можно либо начать второй vertical,
либо перейти к оставшимся пунктам Blueprint roadmap (Business Admin UI,
production hardening) — решение за пользователем.
