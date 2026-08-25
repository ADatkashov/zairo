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
ручное переключение, персистентность после reload), закоммичено и
запушено (`e675523`).

## Архитектурный документ: Country & Multi-Country (2026-08-21)

Пользователь прислал развёрнутый архитектурный бриф (не запрос "сделай
экран X", а полноценная спецификация): страна и язык должны быть
конфигурацией платформенного уровня, а не хардкодом; Казахстан — первый
рынок, не постоянный центр системы; дальше легко должны добавляться
Узбекистан, Кыргызстан, Турция, Россия, США, Европа, Китай. По аналогии
с тем, как раньше был одобрен "Factory Blueprint" и "Factory Design
System" перед реализацией — сначала архитектурный документ, потом
код по фазам с подтверждением. Не начинал писать код в этом шаге.

Перед тем как писать документ, форк-агент проверил реальное состояние
кодовой базы (не строил документ на предположениях):
- `PaymentProvider` (backend) и `LocationService` (`user_app`'s maps)
  уже независимо реализуют ровно тот же паттерн адаптера, который бриф
  просит формализовать — `LocationService`'s собственный doc-комментарий
  прямо говорит "mirrors the PaymentProvider pattern on the backend".
  Это не новая идея для проекта, документ её называет и продолжает.
- Реальные нарушения принципов брифа уже есть в коде: `FactoryPriceText`
  хардкодит `'₸'` дефолтом; `ServiceOffering.currency` — свободная
  строка без валидации; `vertical-beauty`'s `MasterDirectoryService`
  делает `"beauty".equals(vertical)` — не про страну, но та же болезнь
  хардкод-строки, которую бриф просит искоренить; `CurrentUser` —
  готовый прецедент паттерна (статический хелпер поверх
  request-атрибутов, выставленных `JwtAuthFilter`) для будущего
  `CountryContext`/`LocaleContext`; ни одного `Country`/`Locale`
  entity нигде в бэкенде нет; несколько реальных хардкод-строк-ошибок
  на бэкенде процитированы как конкретные примеры для будущей миграции
  на translation-ключи.

Опубликован документ "Factory Country Architecture":
https://claude.ai/code/artifact/987d4f04-9453-48ec-9091-7a4e79316b5f
(оформлен в той же визуальной системе, что и Design System/Blueprint —
палитра/шрифты `core_ui` переиспользованы для консистентности между
всеми архитектурными артефактами проекта).

### Ключевые решения документа
1. **Country ≠ Language** — независимые оси (пример из брифа: KZ+ru,
   KZ+kk, US+ru все валидны), обе читаются из `RequestContext`, нигде
   не выводятся одна из другой.
2. **Country config** — одна запись на рынок (code/name/defaultLanguage/
   supportedLanguages/currency/timezone/formats/taxConfig/featureFlags/
   provider-списки), добавление страны = новая запись, не новый код.
3. **Три класса контента** с разными механизмами перевода, а не один
   универсальный: статичный UI-текст → ARB на фронтенде (уже так и
   работает); доменный контент (название услуги и т.п.) → JSONB-колонка
   `translations` на entity вместо `nameRu`/`nameKz`/`nameEn`; системные
   сообщения → бэкенд отдаёт ключ (`booking.slot_conflict`), каждый
   фронтенд резолвит его через свой же ARB — не строит отдельный
   backend-сервис переводов.
4. **API-контракт** — гибридный, явно выбран и обоснован (не "оба
   варианта возможны" — бриф просил выбрать один и задокументировать):
   системные сообщения — ключ, резолвится на клиенте; доменный контент
   с реальными переводами — полная `translations`-карта либо
   `?resolve=locale` для случаев, где важен размер payload.
5. **Regional adapter pattern** формализован на `PaymentProvider`;
   явно решено НЕ строить `DeliveryProvider`/`SmsProvider`/
   `IdentityProvider`/`TaxProvider` сейчас — это была бы спекулятивная
   абстракция без второй реальной реализации, что прямо противоречит
   давно установленному в проекте принципу "не добавлять абстракцию до
   того, как она реально нужна".
6. **Flutter**: новый общий пакет `packages/core_region` (модель
   Country + форматирование валюты/дат/чисел/телефонов) — но НЕ общий
   пакет переводов между `user_app` и `business_admin` (тот же довод,
   что уже применялся к `core_ui`: контент экранов почти не
   пересекается).
7. **JSONB, не нормализованная `translation`-таблица** для доменных
   переводов — осознанный компромисс под текущий масштаб проекта, с
   явной оговоркой, когда стоит пересмотреть (полнотекстовый поиск по
   переводам).
8. **План внедрения из 6 фаз** (A: `Country`-таблица + `RequestContext`,
   без изменения поведения — B: `core_region` + починка `'₸'`-хардкода —
   C: миграция сообщений на ключи + расширение порядка резолюции языка —
   D: JSONB-переводы доменного контента, отложено до реальной
   потребности — E: адаптеры доставки/SMS, отложено до реальной фичи —
   F: вторая страна целиком, названа реальным acceptance-тестом всей
   архитектуры — та же роль, что у второй вертикали для Core/Vertical
   KPI). Каждая фаза — независимо проверяемый кусок, тем же ритмом
   "маленький шаг + подтверждение", что и весь остальной проект.

### Статус
Документ опубликован; одобрения по нему не было (пользователь сразу
ответил про реализацию — см. ниже). Код в этом шаге не менялся.

## Реализация фаз A–F (2026-08-21)

Пользователь: "да начинай A дальше по очереди сделай полностью до F
второй страна точно будет заложить самого начала... а язык это другое"
— подтвердил, что вторая страна реально будет, и напомнил ключевой
принцип документа (Country ≠ Language) как обоснование, а не новое
требование. Прошёл все 6 фаз за один присест, с реальной проверкой на
каждой. D и E сознательно оставлены как *решение*, а не как недоделка —
у обеих нет ни одного реального потребителя в кодовой базе прямо
сейчас, а строить их сейчас означало бы нарушить тот же принцип
"не добавлять абстракцию, пока она не нужна", который сам документ
устанавливает для регионально-специфичных адаптеров.

### Phase A — `country` таблица + `RequestContext` (бэкенд)
Новый Gradle-модуль `backend/country` (ни от одного другого модуля не
зависит — наоборот, будущие модули будут зависеть от него):
- `Country` entity (`code` — натуральный ключ, ISO 3166-1 alpha-2, не
  суррогатный UUID), `CountryStatus` (DRAFT/ACTIVE/SUSPENDED — та же
  форма, что и `ProviderStatus`), `CountryRepository`,
  `CountryService`/`CountryController` —
  `GET /api/v1/countries` (только ACTIVE), `GET /api/v1/countries/{code}`
  (любой статус, 404 на неизвестный).
- `CountryResolutionFilter`/`CountryContext` — та же форма, что и
  `JwtAuthFilter`/`CurrentUser` в `auth`: фильтр читает заголовок
  `X-Country`, иначе берёт платформенный дефолт (`"KZ"`, честно
  задокументированный как временный, "весь продукт сегодня — только
  Казахстан"), выставляет request-атрибут; `CountryContext` — статический
  хелпер поверх него, но, в отличие от `CurrentUser`, никогда не кидает
  исключение — фильтр гарантирует, что значение всегда выставлено.
- Осознанно НЕ добавлены сейчас в схему: featureFlags, tax/legal-конфиг,
  address/phone-формат, списки провайдеров — ни один из них пока никем
  не читается; будут добавлены в фазе, которая их реально использует.
- `V15__create_country_table.sql` — таблица + сид-строка KZ (реальные
  значения: KZT, Asia/Almaty, kk/ru/en, ACTIVE).
- Тесты: `CountryResolutionFilterTest` (4, модульные, свой test-sourceset
  у `country` — впервые в бэкенде тест живёт не только в `platform-api`,
  т.к. `CountryResolutionFilter`/`CountryContext` package-private
  осознанно) + `CountryApiTests` (Testcontainers, через `platform-api`).
  Полный `./gradlew build` зелёный.

### Phase B — `packages/core_region` + починка `'₸'`-хардкода (Flutter)
Новый общий пакет `packages/core_region`: `Country`-модель (зеркалит
backend'овый JSON 1:1), `currencySymbolFor(code)` (KZT/UZS/KGS/TRY/RUB/
USD/EUR/CNY — валюты из списка стран в брифе; неизвестный код возвращает
сам код, а не молча откатывается на тенге — то самое явное поведение
для "любой будущей страны", которое бриф требует), `RegionDefaults`
(текущий единственный рынок — реальные значения из сида KZ). `core_ui`
теперь зависит от `core_region`; `FactoryPriceText`/`ProviderCard`/
`ServiceRow` — `currencySymbol` стал `String?` (был `= '₸'` буквально в
трёх местах), дефолт резолвится через `RegionDefaults.currencySymbol` —
поведение сегодня не изменилось (по-прежнему ₸), но теперь у "почему
тенге" есть одно названное место в коде, а не мистический литерал внутри
виджета. Тесты: новый `core_region_test.dart` (4), новый regression-тест
в `core_ui` на явный override валюты. `core_ui` 22/22 (было 21),
`user_app` 36/36, `business_admin` 18/18, `flutter build web` собирается
в обоих приложениях.

### Phase C — ключи вместо строк для системных сообщений
Раскопал реальную картину при реализации: бэкенд вообще не отправляет
`ResponseStatusException`'s текст клиенту (Spring по умолчанию не
включает `message` в тело ошибки), и ни один экран/API-слой в обоих
Flutter-приложениях никогда не читает текст ошибки с бэкенда — каждое
сообщение об ошибке пользователю сегодня хардкожено прямо в Dart, по
HTTP-статусу (`reviews_api.dart`: `if (status == 409) throw
ReviewException('This booking already has a review...')`). Это даже
более прямое нарушение принципов документа, чем то, что нашёл
форк-агент до написания архитектуры — и решается ровно так, как
описано в разделе про API-контракт: ключ, не текст, резолвится там, где
есть `BuildContext`.

Мигрировал один полный поток целиком (Review — самый маленький, всего
два сообщения), как доказательство паттерна, а не весь бэкенд разом:
`ReviewException` теперь несёт `ReviewErrorKey` enum
(`duplicateOrNotCompleted`/`invalidRating`) вместо голого `String
message`; `reviews_api.dart` кидает по enum, не по тексту;
`ReviewException.localizedMessage(AppLocalizations l10n)` резолвит через
новые ARB-ключи (`errorReviewDuplicateOrNotCompleted`,
`errorReviewInvalidRating`, `errorReviewSubmitFailed`) на всех трёх
языках; `review_section.dart`'s catch-блоки резолвят на месте, где
`context` доступен (`ReviewsApi` — обычный Riverpod-класс без
`BuildContext`, поэтому резолюция физически не могла случиться на
уровне API). Тест обновлён под новый конструктор; т.к. английский ARB
текст совпадает с прежним хардкодом дословно, видимый текст в тесте не
изменился. `user_app` 36/36.

**Остальные исключения (`BookingException`, `AuthException`,
`PaymentException`, `BeautyException` в `user_app`, и весь аналогичный
слой в `business_admin`) — тот же самый механический паттерн, не
сделаны в этом проходе.** Названо явно как продолжение "по модулю за
раз", а не забыто.

### Phase D и E — сознательно не реализованы
D (JSONB `translations` на доменных сущностях) и E (адаптеры доставки/
SMS/etc.) не имеют сейчас ни одного реального потребителя — ни один
продавец не пытается завести второй язык на своей услуге, ни одна
фича доставки/уведомлений не существует даже как задача. Строить их
сейчас значило бы нарушить тот же принцип "не добавлять абстракцию
раньше реальной потребности", который сам документ устанавливает в
разделе про regional adapters. Данные модели/интерфейсы для них уже
описаны в архитектурном документе — реализация ждёт первого реального
триггера (продавец, которому реально нужен второй язык; фича доставки,
которой реально нужен провайдер).

### Phase F — вторая страна как acceptance-тест
`V16__seed_uzbekistan_country_draft.sql` — Узбекистан, статус `DRAFT`,
реальные значения (UZS, Asia/Tashkent, uz/ru/en). Ключевое: это ровно
одна строка миграции, ноль строк кода в `CountryController`/
`CountryService`/`CountryRepository` — они уже полностью общие, без
единого упоминания "KZ" где-либо в бизнес-логике. Новый тест
(`aSecondCountrySeededAsDraftIsFetchableByCodeButExcludedFromThePublicList`)
проверяет именно это: `GET /api/v1/countries/UZ` отдаёт полные данные
через тот же код, что и KZ; `GET /api/v1/countries` (публичный список)
корректно не включает DRAFT-страну. Живая проверка через curl
подтвердила то же самое на реальном бэкенде: активный список — только
KZ, `/countries/uz` — полные узбекские данные, `/countries/ZZ` — 404.

### Статус
Все 6 фаз реализованы (A/B/C/F — код и тесты; D/E — осознанно
отложены, задокументировано почему), полностью проверено (unit-тесты
на бэкенде и во всех трёх Flutter-пакетах/приложениях, живая проверка
через curl). По просьбе пользователя ("Начни с фазы A") закоммичено и
запушено **отдельными коммитами по фазам**, не одним большим:
Phase A `020a5f5`, Phase B `7ccac23`, Phase C `7518bb0`, Phase F
`3c9974f` (D/E — без коммита, т.к. без кода).

## Мастер-архитектура платформы (2026-08-21)

Пользователь прислал ещё более широкий бриф — 52 раздела: Factory не
как одно приложение и не как набор страновых приложений, а как
"фабрика композиции" (multi-tenant, multi-marketplace, multi-industry,
multi-country, с Money/Tax/Fiscalization/Delivery/Identity/Compliance/
Events/RBAC/Admin/Observability и т.д.). Финальный раздел брифа сам
явно говорит: "Do not over-engineer implementation details prematurely.
First establish clean architectural boundaries..." — это прямая
инструкция, что этот шаг снова документ, не код (та же логика, что и
с Country Architecture ранее).

Опубликован документ "Factory Master Architecture":
https://claude.ai/code/artifact/81acb780-9136-4e4d-932a-7ee5602c96bd
— не дублирует Country Architecture (тот документ остаётся детальным
описанием оси Market/Localization), а даёт карту верхнего уровня и
явно на неё ссылается.

### Подход
Вместо того чтобы одинаково подробно расписать все 52 пункта (это
дало бы либо нереалистичный объём, либо поверхностность), документ:
1. Даёт единожды полную целевую иерархию (Platform/Tenant/Marketplace/
   Industry/Market/Localization/Core Marketplace/Regional Integrations/
   External Providers) одной mermaid-диаграммой.
2. **Честно сопоставляет её с реальным состоянием кода** — таблица по
   каждому измерению: что реально построено (Country — Phase A–F;
   Core Marketplace — весь текущий бэкенд; Industry — `vertical`-поле +
   `vertical-beauty` модуль), что осознанно отложено (Tenant/
   Marketplace/Region — ни разу не понадобились), что частично есть
   (Identity/RBAC — 3 роли + ownership-проверки, не общая
   Role/Permission/Scope модель).
3. Переиспользует и явно называет "лакмусовую бумажку", уже дважды
   доказанную в проекте (Payments/Maps органически,
   Country/core_region осознанно): не строить абстракцию, пока нет
   реального второго потребителя.
4. Проверил реальную схему БД перед тем как писать раздел про Money:
   `ServiceOffering.price`+`currency`, `Booking.totalPrice` (без
   currency вообще), `Payment.amount`+`currency` — три независимые,
   задублированные пары amount+currency, нигде не собранные в один
   тип. Это единственное место во всём документе, где реальный
   триггер уже есть сегодня (в отличие от Tax/Delivery/Identity-
   провайдеров, у которых пока ноль реальных потребителей) — назван
   как самая дешёвая и обоснованная штука, которую стоит сделать
   в следующий раз.
5. Явно прогнал раздел "What NOT to build" (§50 брифа) как чек-лист
   против реального кода — чисто везде, кроме одного: хардкод
   `"beauty".equals(vertical)` в `MasterDirectoryService`, который
   теперь назван уже в третий раз за проект (research-форк, Country
   Architecture, этот документ) и всё ещё не исправлен.
6. Закрывает документ явным, дисциплинированным списком из 4 пунктов
   "что реально стоит делать дальше" — специально НЕ превращает 52
   раздела брифа в 52-пунктный бэклог, это и есть послание документа
   пользователю: сдержанность — не пробел в архитектуре, а её цель.

### Статус
Документ опубликован. Код не менялся — по прямой инструкции самого
брифа не форсировать реализацию раньше реальной необходимости.

## Следующий шаг — рекомендация архитектора
Из документа: (1) общий тип `Money` вместо трёх задублированных пар
amount+currency — самое дешёвое и обоснованное; (2) наконец исправить
хардкод `"beauty".equals(vertical)`; (3) доделать миграцию исключений
на ключи (`BookingException`/`AuthException`/`PaymentException`/
`BeautyException` + `business_admin`); (4) докатить `AppLocalizations`
до остальных экранов `user_app` и повторить в `business_admin`. Все
остальные темы брифа (Tenant/Marketplace/Region, Events, общий RBAC,
Tax/Delivery/Identity-провайдеры, единый ConfigurationEngine) сознательно
остаются спроектированными, но не реализованными — ждут своего
реального триггера.

## Реализация рекомендованных 4 пунктов (2026-08-21)

Пользователь подтвердил делать все 4 пункта по порядку, одним общим
коммитом, с явным запретом расширять scope на Tenant/Marketplace/
Region/RBAC/ConfigurationEngine/Events/Tax-Delivery-Identity-провайдеры
без реального триггера.

### Пункт 1 — общий тип `Money` (сделано)
- Новый foundational-модуль `backend/money` (зависимостей ни на что не
  имеет, зависят от него `services`/`booking`/`payments`/`platform-api`)
  — `Money` (`@Embeddable`, `BigDecimal amount` + validated ISO 4217
  `currencyCode` через `java.util.Currency`, не отрицательный,
  value-equality через `compareTo`, не `equals`). 8 unit-тестов.
- `ServiceOffering.price`, `Payment.amount` переведены на `@Embedded
  Money` через `@AttributeOverrides` **без изменения публичных
  конструкторов/геттеров** — колонки в БД те же (`price`/`currency`,
  `amount`/`currency`), DTO не менялись.
- `Booking` **не имел** своей валюты вообще (баг с самого начала) —
  добавлено по-настоящему: `totalPrice` теперь `@Embedded Money`,
  новая колонка `booking.currency` (Flyway `V17`, backfill из
  `service.currency` для существующих строк). `BookingResponse` DTO
  получил новое поле `currency` — аддитивно, не ломает старых клиентов.
- Попутно найден и исправлен реальный скрытый баг: `Payment` брал
  валюту из собственного независимого конфига
  (`app.payments.currency`), который мог разойтись с валютой брони.
  Теперь `Payment` наследует валюту от `booking.getCurrency()`, единый
  источник — переименованный `app.platform.default-currency`,
  читается только в `BookingService`.
- **Осознанно не сделано**: exchange rates, конвертация мультивалюты,
  исторические курсы, отдельный currency engine — ни одного реального
  потребителя.

### Пункт 2 — хардкод `"beauty".equals(vertical)` (сделано)
- `MasterDirectoryService`: проверка вынесена в именованный
  `isBeautyVertical(Provider)`, стала case/whitespace-tolerant
  (`" Beauty "` теперь тоже проходит) — `Provider.vertical` в системе
  и так непрозрачная нетипизированная строка (Core её вообще не
  валидирует, подтверждено через grep и доккомент `Provider.java`), так
  что нормализация — реальное устранение хрупкости, а не
  гипотетическое. Новый тест
  `acceptsMasterCreationRegardlessOfVerticalCasingOrWhitespace`.
- **Важная переоценка по ходу работы**: изначально предполагалось, что
  сама проверка — нарушение архитектуры (Core, ветвящийся по
  конкретному vertical). После грепа выяснилось, что это не так: Core
  (`providers`-модуль) нигде не читает и не валидирует `vertical` —
  проверка живёт целиком внутри `vertical-beauty` и валидирует
  собственное предусловие модуля. Архитектурно это ок; улучшение —
  только устойчивость к регистру/пробелам.
- Регрессия-тест на «Core не завязан на конкретное значение "beauty"»
  фактически уже покрыта существующим тестом
  `rejectsMasterCreationOnANonBeautyProvider` (использует `"auto-" +
  runId` как произвольный non-beauty vertical, не привязан к
  конкретному второму vertical).

### Пункт 3 — исключения → message keys (сделано, оба Flutter-приложения)
Продолжение паттерна, доказанного на Reviews (Phase C выше).
- `user_app`: `AuthException`, `BookingException`, `PaymentException`,
  `BeautyException` — у каждого теперь `enum ...ErrorKey` +
  `localizedMessage(AppLocalizations l10n)` вместо голого `String
  message`; throw-сайты (`auth_api.dart`, `booking_api.dart`,
  `payments_api.dart`, `beauty_api.dart`) кидают по enum. Экраны, что
  ловят эти исключения (`LoginScreen`, `RegisterScreen`,
  `ProviderDetailScreen._book()`), резолвят текст на месте через
  `AppLocalizations.of(context)!` — API-слой по-прежнему без
  `BuildContext`, резолюция только на UI-границе.
- `business_admin` **не имел вообще никакой l10n-инфраструктуры**
  (ни `flutter_localizations`/`intl`, ни ARB, ни `l10n.yaml`) — заведена
  с нуля тем же паттерном, что в `user_app` (минимальный: `MaterialApp`
  берёт `localizationsDelegates`/`supportedLocales` из
  `AppLocalizations`, локаль не закреплена — следует системной, своего
  переключателя языка в `business_admin` пока нет). `AuthException`
  (единственный класс исключений во всём `business_admin`) переведён
  на тот же `enum`-паттерн.
- Ни одного нового API-контракта, ни одной новой системы локализации —
  везде переиспользован уже существующий ARB/intl/`AppLocalizations`
  механизм. `backend` не менялся под этот пункт: сообщения и раньше не
  доходили до клиента текстом (Spring не шлёт `message` по умолчанию),
  вся логика "текст по HTTP-статусу" и так жила во Flutter — то, что
  мигрировало, ключи, а не источник сообщений.

### Пункт 4 — AppLocalizations (сделано частично, явно не всё)
- `user_app`: `LoginScreen`, `RegisterScreen` полностью переведены на
  `l10n.*` (не только строка ошибки — раз уж экран трогать пришлось для
  пункта 3, полностью локализован за один проход, без повторного
  захода). `ProviderDetailScreen._book()` — весь catch-блок и все
  snackbar-сообщения переведены на `l10n.*`; остальная часть экрана
  (заголовки секций, кнопка "View on map", пустые состояния) **не
  тронута**.
- `business_admin`: заведена l10n-инфраструктура (см. пункт 3) +
  `LoginScreen`/`RegisterScreen` полностью локализованы (та же причина
  "раз уж трогаем экран для AuthException").
- **Сознательно НЕ сделано в этом проходе** (весь остальной чек-лист
  из брифа "buttons, labels, validation, empty states, error states,
  dialogs, notifications, navigation, forms, status messages" за
  пределами Login/Register/booking-ошибок):
  - `user_app`: Home/Search (`DiscoveryScreen`), `MyBookingsScreen`
    (кроме уже переведённых ошибок), `FavoritesScreen`, `ProfileScreen`,
    `MockMapScreen`, `MasterPortfolioScreen`, диалог отзыва
    (`_LeaveReviewDialog`), карточки провайдера/сервиса.
  - `business_admin`: `DashboardScreen`, `SalonDetailScreen` (все 4
    секции), `ModerationScreen`.
  - Это не оговорка — сделан честный выбор закрыть Item 1-3 полностью
    и заложить настоящий фундамент под Item 4 (работающая
    инфраструктура + доказанный на реальных экранах паттерн в обоих
    приложениях), а не размазать оставшийся бюджет по десяткам
    экранов частично. Список экранов выше — точный remaining scope
    следующего прохода по Item 4, ничего придумывать заново не нужно.
  - kk/ru/en — единственные поддерживаемые языки, как и было; носитель
    казахского языка переводы ещё не проверял (см. более раннюю
    заметку про Kazakh localization).

### Проверено
- Backend: `./gradlew build` (весь монолит, все модули + Testcontainers-
  тесты `platform-api`, включая `MoneyTest` (8/8) и обновлённый
  `BeautyApiTests`) — BUILD SUCCESSFUL.
- `user_app`: `flutter analyze` — чисто; `flutter test` — 36/36 (включая
  фикс двух ранее сломанных тестов — `provider_detail_screen_test.dart`
  и `favorite_button_test.dart` не оборачивали `MaterialApp` в
  `localizationsDelegates`, из-за чего `AppLocalizations.of(context)`
  падал с `null`-check — тот же паттерн фикса, что уже был найден в
  Phase C для `review_section_test.dart`/`settings_screen_test.dart`).
- `business_admin`: `flutter analyze` — чисто; `flutter test` — 18/18.
- Архитектурный чек-лист "должно остаться чистым" перепроверен через
  grep после всех изменений: нет `nameKz`/`nameRu`/`nameEn`, нет
  `KZOrderService`/`UZOrderService`/`TROrderService`, нет хардкода
  `"beauty"` вне `vertical-beauty`, нет хардкода `₸`/других символов
  валют в коде — чисто.

### Возможные будущие триггеры для отложенных компонентов
(не построены сейчас, ждут реального повода — из документов Country
Architecture и Master Architecture, повторено здесь коротко, не
пересказ архитектуры):
- **Tenant/Marketplace/Region** — когда появится второй реальный
  оператор платформы или второй географический рынок с иной бизнес-
  логикой (не просто другой `country`-строкой).
- **Общий RBAC/Permission-движок** — когда ролей/скоупов станет больше
  трёх текущих (`CUSTOMER`/`PROVIDER_OWNER`/`ADMIN`) настолько, что
  точечные ownership-проверки перестанут быть читаемыми.
- **ConfigurationEngine** — когда конфигурация, специфичная для
  vertical/страны, перестанет умещаться в `application.yml` +
  `RegionDefaults`.
- **Events/Kafka** — когда появится реальный второй процесс/сервис,
  которому нужны доменные события за пределами текущего
  `ApplicationEventPublisher` в одном JVM (см. ADR-0002).
- **Tax/Delivery/Identity/Notification/Search/Analytics-провайдеры** —
  каждый ждёт своего первого реального потребителя (как уже было с
  `PaymentProvider`/`LocationService` — интерфейс появился одновременно
  с первой mock-реализацией, не раньше).
- **Exchange rates/мультивалюта** — когда появится второй реальный
  рынок с другой валютой одновременно с первым (сейчас вся платформа
  работает в одной валюте за раз).

### Текущий статус
Пункты 1-4 (в объёме, описанном выше) закоммичены и запушены
(`ad6844b`). Пользователь подтвердил продолжать Item 4 дальше — сразу
после коммита выбрал "user_app" следующим шагом.

## Item 4, продолжение — весь user_app локализован (2026-08-21)

Пользователь выбрал "Продолжить Item 4 — user_app" из предложенных
вариантов после коммита `ad6844b`. Закрыт весь remaining scope,
зафиксированный в предыдущем разделе: Home/Search, MyBookingsScreen
(статусы и дата брони), FavoritesScreen, ProfileScreen, MockMapScreen,
MasterPortfolioScreen, диалог отзыва, PaymentStatusChip и оставшийся
UI-каркас `ProviderDetailScreen` (заголовки секций, бейджи, кнопка
"View on map", тултип, длительность услуги, названия месяцев в
датах слотов/броней).

- Новый общий хелпер `lib/core/formatting/month_day_time.dart`
  (`formatMonthDayTime(l10n, dateTime)`) — единый формат "MMM d, HH:mm"
  с локализованными сокращениями месяцев (12 ARB-ключей
  `monthJan`..`monthDec`), переиспользуется `MyBookingsScreen` и
  `ProviderDetailScreen` вместо двух независимых копий одного и того же
  форматтера.
- Статусы брони (`CONFIRMED`/`COMPLETED`/`CANCELLED`) и оплаты
  (`SUCCEEDED`/`FAILED`) получили явные ARB-ключи вместо generic
  capitalize; для любого нераспознанного статуса (будущий backend enum)
  сохранён тот же generic-capitalize fallback, что был раньше — не
  ломается на новых статусах без немедленного добавления перевода.
- `ProviderCard`'s "X.X km · vertical" остаётся с `vertical` как
  необработанным placeholder'ом (реальные данные бэкенда, не
  UI-текст) — намеренно не переведено, чтобы не завести
  vertical-specific хардкод локализации на UI-слое (тот же принцип, что
  и в пункте 2 про `"beauty".equals(vertical)`).
- Language picker (`SettingsScreen`) показывает названия языков на них
  же самих ("English"/"Русский"/"Қазақша") — намеренно не переведено,
  стандартный UX для селектора языка (пользователь должен узнать
  название своего языка независимо от текущей локали интерфейса).
  Mock-локация "Almaty" на Home тоже намеренно не переведена — это
  тестовые данные (см. комментарий в коде про `location_service.dart`),
  не UI-строка.
- ~85 новых ARB-ключей на английском + полные переводы на ru/kk.

Проверено: `flutter analyze` — чисто; `flutter test` — 36/36 (после
добавления `localizationsDelegates`/`supportedLocales` в 7 тестовых
файлов, у которых экраны раньше не читали `AppLocalizations.of(context)`
и поэтому обходились без делегатов — та же ошибка `null`-check, что уже
чинилась для `provider_detail_screen_test.dart`/`favorite_button_test.dart`
в предыдущем разделе, просто на новых файлах). Grep по `lib/features`
подтвердил: единственные оставшиеся хардкоженные `Text(...)`-литералы —
два намеренных исключения выше, ничего не упущено.

**`user_app` теперь полностью на `AppLocalizations`.** Оставшийся scope
Item 4 — только `business_admin`: `DashboardScreen`, `SalonDetailScreen`
(4 секции), `ModerationScreen` (Login/Register там уже локализованы, см.
предыдущий раздел).

### Текущий статус
Закоммичено и запушено (`8a57f32`).

## Item 4, финал — весь business_admin локализован (2026-08-21)

Пользователь выбрал "Item 4 — business_admin" следующим шагом. Закрыт
весь оставшийся scope: `DashboardScreen` (приветствие, форма создания
салона, диалог "Add another salon"), `ModerationScreen`, и самый
большой экран проекта — `SalonDetailScreen` (4 секции: Services,
Availability, Masters, Bookings + диалог редактирования салона) со
всеми 5 CRUD-диалогами (`AddServiceDialog`, `AddSlotDialog`,
`AddMasterDialog`, `AddPortfolioItemDialog`,
`ManageMasterServicesDialog`).

- Новый `lib/core/formatting/month_day_time.dart` в `business_admin` —
  та же схема, что и в `user_app` (независимая копия, не общий пакет:
  два приложения делят только `core_ui`/`core_network`/`core_storage`,
  не фичи и не эту утилиту — уже устоявшийся в проекте выбор).
- Статусы провайдера (`ACTIVE`/`PENDING`/`SUSPENDED`) и брони
  (`CONFIRMED`/`COMPLETED`/`CANCELLED`) получили явные ARB-ключи с тем
  же generic-capitalize fallback на нераспознанный статус, что и в
  `user_app`. Vertical (`beauty` и т.д.) остаётся непереведённым сырым
  значением — тот же принцип "не заводить UI-хардкод под конкретный
  vertical", что и в пункте 2 и в `user_app`'ском `ProviderCard`.
- ~90 новых ARB-ключей на английском + переводы на ru/kk. Много
  переиспользуемых generic-ключей (`cancelButton`, `saveButton`,
  `addButton`, `durationMinutesLabel`, `errorServicesLoadFailed` и
  т.д.) — сознательно не заводил отдельный ключ на каждый диалог,
  раз текст физически одинаковый ("Cancel" в диалоге создания слота и
  в диалоге редактирования услуги — один и тот же ключ).

Проверено: `flutter analyze` — чисто; `flutter test` — 18/18 (после
добавления `localizationsDelegates`/`supportedLocales` в 4 тестовых
файла — `auth_gate_test.dart`, `dashboard_screen_test.dart`,
`moderation_screen_test.dart`, `salon_detail_screen_test.dart` — тот же
паттерн фикса, что уже применялся трижды в этой сессии). Grep по
`lib/features` подтвердил: непереведённых `Text(...)`/`labelText`/
`tooltip`/`title` литералов не осталось.

**И `user_app`, и `business_admin` теперь полностью на
`AppLocalizations` (kk/ru/en).** Item 4 закрыт целиком. Из
рекомендованных архитектором 4 пунктов не осталось ни одного открытого
подпункта — остаётся только уже названная ранее "на будущее" работа:
носитель казахского языка ещё не проверял переводы вживую (см. более
раннюю заметку), и все темы, сознательно спроектированные, но не
реализованные (Tenant/Marketplace/Region/RBAC/Events/провайдеры) —
ждут реального триггера, см. список выше.

### Текущий статус
Закоммичено и запушено (`1b6d7a3`).

## Мелкая полировка UX (2026-08-21)

Пользователь выбрал из предложенных "мелкая полировка UX" — два
пункта, названных ещё раньше как "на будущее": naming-несоответствие
`ProviderCard`/`FactoryProviderCard` и Bookings/Favorites не как полноценные
вкладки нижней навигации.

### `ProviderCard` → `FactoryProviderCard` в `core_ui`
Каждый виджет в `core_ui` носит префикс `Factory` (`FactoryBadge`,
`FactoryAvatar`, `FactoryPriceText` и т.д.), кроме одного. Причина
нашлась в самом коде: `user_app` держит собственный класс-обёртку,
тоже названный `ProviderCard` (маппит `ProviderSearchResult` на поля
карточки) — из-за коллизии имён каждый импортирующий `core_ui.dart`
экран был вынужден писать `hide ProviderCard`. Переименовал класс и
enum (`ProviderCardLayout` → `FactoryProviderCardLayout`) в `core_ui`,
обновил тесты `core_ui` — теперь у `user_app`'ского адаптера остаётся
короткое имя `ProviderCard` как у собственного, не конфликтующего типа,
а `hide ProviderCard` в трёх экранах (`home_screen.dart`,
`search_screen.dart`, `favorites_screen.dart`) стал не нужен и убран.
`core_ui` 22/22, `user_app` не ломается (проверено analyze+test).

### Bookings и Favorites — полноценные вкладки нижней навигации
Дизайн-артефакт v0.2 предписывал 5 вкладок (Home/Search/Bookings/
Favorites/Profile) с самого начала работы над design system, но при
реализации Home/Search (более ранняя фаза) осознанно отложили
Bookings/Favorites-вкладки как отдельное решение. Пользователь выбрал
"5 вкладок по артефакту" — конфликт с текущим Settings-таб решён
переносом Settings с нижней навигации на кнопку-шестерёнку в AppBar
экрана Profile (работает независимо от статуса логина, т.к. тема/язык
не требуют авторизации).

Ключевое архитектурное следствие: `MyBookingsScreen`/`FavoritesScreen`
раньше принимали `userId` через конструктор (пушились только из уже
залогиненного `ProfileScreen`). Теперь это вкладки-пиры для Home/
Search/Profile, достижимые независимо от статуса логина — оба экрана
переписаны, чтобы самостоятельно читать `authControllerProvider` и
показывать новый общий виджет `LoggedOutGate` (иконка + сообщение +
кнопка "Войти", ведущая на `LoginScreen`) вместо падения без
пользователя. `ProfileScreen` лишился кнопок "My bookings"/
"My favorites" (они больше не нужны — те же экраны теперь прямые
вкладки).

Новые ARB-ключи: `navBookings`/`navFavorites` (подписи вкладок),
`bookingsLoggedOutPrompt`/`favoritesLoggedOutPrompt` (текст в
`LoggedOutGate`), `settingsButtonTooltip`. Удалён более не используемый
`navSettings` (Settings больше не таб).

Тесты: добавлены новые кейсы "shows a login gate when logged out" для
`MyBookingsScreen`/`FavoritesScreen` (по образцу уже существующего
`favorite_button_test.dart`'s logged-out кейса) — `user_app` 38/38
(было 36, +2 новых). `flutter analyze` — чисто.

**Живая проверка в браузере** (по правилу "для UI — открыть и
проверить"): поднял backend (`bootRun`) + `flutter run -d chrome`,
подтвердил скриншотами — нижняя навигация показывает все 5 вкладок
(Главная/Поиск/Брони/Избранное/Профиль) с реальными данными с backend;
клик по "Брони" в незалогиненном состоянии показывает `LoggedOutGate`
("Войдите, чтобы увидеть свои бронирования" + кнопка "Вход"); вкладка
"Профиль" показывает шестерёнку настроек в AppBar; клик по шестерёнке
открывает `SettingsScreen` (тёмная тема + язык) поверх вкладки, без
авторизации. После проверки backend/dev-сервер остановлены (не
оставлены висеть).

### Текущий статус
Закоммичено и запушено (`ba79331`).

## Android Studio/монорепо: пустая структура проекта + сломанная Android-сборка business_admin (2026-08-21)

Пользователь сообщил: при открытии проекта в Android Studio не видно
папок/структуры и не получается запустить мобильную часть, чтобы
самому проверять.

### Причина 1 — открыт корень монорепо, а не конкретное приложение
`.idea/AndroidProjectSystem.xml` в корне репозитория был настроен как
`com.android.tools.idea.GradleProjectSystem` (Gradle-Android проект) —
но реального Android/Gradle-проекта в корне нет (его убрали в самом
начале сессии, см. более раннюю заметку выше). У каждого приложения
свой `android/` под `apps/<name>/`. Открытие корня показывает пустую
структуру, потому что Android Studio ищет Gradle-проект там, где его
нет. Исправлено: удалён устаревший `.idea/` в корне (в git никогда не
попадал, регенерируется автоматически) — с подтверждения пользователя.
В `README.md` добавлен раздел "Как открыть в Android Studio",
явно требующий открывать `apps/user_app`/`apps/business_admin` как
отдельные самостоятельные проекты, не корень.

### Причина 2 — реальный, ранее не обнаруженный баг: Android-сборка `business_admin` не собиралась вообще
Пока разбирался с первой причиной, проверил `flutter build apk --debug`
для обоих приложений на всякий случай — и оказалось, что
`business_admin` никогда не собирался под Android за всю историю
проекта (в SESSION_NOTES вся живая проверка business_admin шла только
через `flutter run -d chrome`). Две реальные проблемы:
1. `compileSdk` не был поднят до 37 (нужно для `flutter_secure_storage`)
   — тот же фикс, что раньше сделан только для `user_app`, был упущен
   при создании `business_admin` позже по времени.
2. `file_picker: 12.0.0-beta.1` (специально запиненная версия — см.
   более раннюю заметку про зависание на web у стабильной 12.0.0) несёт
   баг в своём `android/build.gradle`: Kotlin-плагин самоприменяется
   только при AGP < 9; на AGP 9.1.0 (наш случай) он предполагает, что
   Kotlin-поддержку включит кто-то другой — но никто не включал, из-за
   чего `FilePickerPlugin.kt` вообще не получал задачу компиляции, и
   сгенерированный Java-регистратор плагинов падал с "cannot find
   symbol: class FilePickerPlugin".

Исправлено в `apps/business_admin/android/build.gradle.kts` —
`subprojects`-блок, точечно принудительно применяющий
`org.jetbrains.kotlin.android` именно к подпроекту `file_picker`
(применение на уровне `:app` не сработало — не распространяется на
отдельный included-подпроект), плюс явная фиксация JVM target 17 для
Kotlin-задач этого подпроекта (иначе конфликтует с Java target 17
приложения — Kotlin по умолчанию целится в 21). Плюс `compileSdk = 37`
в `apps/business_admin/android/app/build.gradle.kts`, как у `user_app`.

Проверено: `flutter build apk --debug` — успешно в обоих приложениях;
`business_admin` `flutter analyze` — чисто, `flutter test` — 18/18
(регрессий нет).

**На заметку**: живая проверка через `flutter run -d chrome` не
доказывает, что Android/iOS/desktop-сборка вообще работает — у каждого
приложения в монорепо нужно отдельно проверять целевую платформу,
"уже проверяли похожее приложение" не переносится автоматически.

### Текущий статус
Закоммичено и запушено (`0974480`).

## business_admin: добавлена платформа iOS (2026-08-21)

В ходе разбора Android-проблем выяснилось: у `business_admin` нет
папок `ios/`, `linux/`, `macos/` вообще — только `windows/` (у
`user_app` есть все). Пользователь попросил добавить iOS и Windows,
без обязательной проверки сборки прямо сейчас (Xcode на этой машине
нет физически; Windows desktop-сборка блокирована отсутствующим
Visual Studio C++ toolchain, известное давнее ограничение машины) —
проверим оба позже.

- Windows у `business_admin` уже существовал и полностью настроен
  (`windows/runner/Runner.rc` — корректное имя `business_admin`, не
  placeholder) — трогать не потребовалось.
- iOS добавлен через `flutter create --platforms=ios --org com.zairo .`
  — bundle id получился `com.zairo.businessAdmin`, согласовано со
  схемой `user_app` (`com.zairo`) и Android-namespace `business_admin`
  (`com.zairo.business_admin`).
- **Побочный эффект команды, исправлен вручную**: `flutter create
  --platforms=ios .` на существующем проекте неожиданно перезаписал
  `.metadata`, стерев записи migration-платформ `android`/`web`/
  `windows`, оставив только `ios`. Чисто bookkeeping-файл для `flutter
  migrate`, не влияет на сборку, но восстановил все записи вручную
  (сверился с форматом в `user_app/.metadata`) — на будущее: после
  `flutter create --platforms=X .` на существующем проекте всегда
  проверять `git diff .metadata`, команда не строго аддитивна.

Проверено: `git status` подтвердил, что затронуты только `.metadata` и
новая папка `ios/` (ничего в `android/`, `windows/`, `lib/` не
задето); `flutter analyze` — чисто. Сборка iOS/Windows намеренно НЕ
проверялась в этом шаге.

### Текущий статус
Закоммичено и запушено (`63551a4`).

## Production-ready MVP, Phase 1 — Item 1: отмена брони клиентом (2026-08-21)

Пользователь прислал развёрнутое ТЗ на перевод Factory из "технически
рабочего MVP" в "production-ready MVP" — 4 фазы (критический функционал,
search/discovery, business admin UX, дизайн-система), с явным повтором
принципа "реальная потребность важнее архитектурной сложности" и тем же
списком запрещённых заранее абстракций (Tenant/Marketplace/RBAC/Kafka/
провайдеры и т.д.). Начал строго по заявленному порядку: анализ кода
перед реализацией, один пункт за раз, компиляция+тесты после каждого
крупного изменения.

**Phase 1, пункт 1 — CUSTOMER может отменить бронь.** Анализ показал:
`BookingStatus.CANCELLED` уже существовал в enum (заготовлен заранее),
но ни разу не устанавливался — метода отмены не было вообще.

Backend:
- `Booking.markCancelled()`, `AvailabilitySlot.markOpen()` — симметрично
  существующим `markCompleted()`/`markBooked()`.
- `BookingService.cancelBooking(bookingId, callerId)`: 404 если брони
  нет, 403 если бронь не принадлежит вызывающему, 409 если статус не
  CONFIRMED (нельзя отменить уже отменённую/завершённую) — тот же паттерн
  guard'ов, что у `completeBooking`. Слот освобождается обратно в OPEN.
  Осознанно НЕ стал добавлять `@Version`-оптимистичную блокировку на
  Booking (в отличие от AvailabilitySlot) — риск двойной отмены только
  от одного и того же клиента (двойной тап), а не от гонки между чужими
  пользователями, как у бронирования слота; статус-guard внутри
  транзакции уже этого достаточно, тот же уровень строгости, что у
  `completeBooking`.
- `POST /api/v1/bookings/{id}/cancel` — защищён `CurrentUser.requireUserId`
  (модуль `booking` уже зависел от `auth`).
- **Возврат платежа через существующий payment abstraction, без
  добавления зависимости `booking → payments`** (это создало бы цикл,
  т.к. `payments → booking` уже существует): новый `BookingCancelledEvent`
  публикуется по тому же ADR-0002 паттерну in-process событий, что уже
  доказан на `BookingConfirmedEvent`. Слушатель `BookingCancelledPaymentListener`
  живёт в модуле `payments` (он и так уже зависит от `booking`) и вызывает
  `PaymentsService.refundPayment`, если у брони был успешный платёж.
- **Реальный баг, найденный и исправленный по ходу**: `@TransactionalEventListener(phase = AFTER_COMMIT)`
  без `@Transactional(propagation = REQUIRES_NEW)` на самом методе-слушателе
  выглядел рабочим (возвращал `REFUNDED` из `refundPayment`), но НЕ
  сохранялся в БД — слушатель "присоединялся" к уже закоммиченной
  транзакции вместо открытия новой, и запись молча терялась. Нашёл через
  диагностическое логирование (метод реально выполнялся и возвращал
  правильный статус, но повторный HTTP GET показывал старое значение).
  Исправлено добавлением `@Transactional(propagation = Propagation.REQUIRES_NEW)`
  на метод слушателя — стандартный, задокументированный паттерн Spring
  для записи в БД из AFTER_COMMIT-хуков.
- `PaymentProvider`/`MockPaymentProvider` уже были готовы под реальный
  провайдер (charge/refund/status/failure) — ничего менять не пришлось,
  архитектура уже удовлетворяет требованию "production-ready payment
  abstraction" из ТЗ.

Flutter (`user_app`): `BookingApi.cancelBooking` (403→`notYourBooking`,
409→`notCancellable`), кнопка "Cancel booking" на карточке брони (только
для CONFIRMED) с диалогом подтверждения, инвалидация
`myBookingsProvider`/`paymentForBookingProvider` после успеха,
`PaymentStatusChip` получил статус REFUNDED (`FactoryBadgeVariant.limited`).
Новые ARB-ключи (en/ru/kk) для всех новых строк.

Тесты: backend — 2 новых теста в `BookingApiTests` (успешная отмена +
освобождение слота + повторная отмена = 409; чужая бронь = 403,
без токена = 401, завершённая бронь = 409) + 1 новый тест в
`PaymentsApiTests` (отмена оплаченной брони автоматически возвращает
деньги) — `./gradlew build` BUILD SUCCESSFUL, весь бэкенд включая новые
тесты. Flutter — 3 новых виджет-теста (кнопка видна только для CONFIRMED,
полный флоу подтверждения+отмены+снекбар, читаемая ошибка при отказе) —
`user_app` 41/41 (было 38), `flutter analyze` чисто.

**Живая проверка через curl против реально запущенного backend** (не
только Testcontainers): полный цикл owner→customer→provider→service→
slot→booking→payment→cancel — подтверждено кодами и телами ответов:
бронь CONFIRMED→CANCELLED, слот BOOKED→OPEN, платёж SUCCEEDED→REFUNDED
автоматически, повторная отмена — 409. Backend остановлен после проверки.

### Текущий статус
Закоммичено и запушено (`7918d11`).

## Production-ready MVP, Phase 1 — Item 2: Password Reset (2026-08-21)

**Backend.** Заведён минимальный, но реальный модуль `notifications`
(до этого — пустой каркас с Phase 1): `NotificationService` +
`EmailNotificationProvider` (интерфейс) + `LoggingEmailNotificationProvider`
— единственная реализация, логирует письмо вместо реальной отправки по
SMTP (нет провайдера/credentials). Явно НЕ mock в духе
`MockPaymentProvider` — письмо реально "доставляется" в лог, разработчик
может прочитать код сброса прямо оттуда; замена на реальный провайдер
(JavaMailSender/SendGrid/SES) — drop-in за тем же интерфейсом. Это ровно
удовлетворяет требованию ТЗ "подготовить notification abstraction так,
чтобы reset message могло использовать email provider", без забегания
вперёд на Push/SMS (у них пока нет потребителя — появится в Item 3).

`auth` модуль: `PasswordResetToken` (точная копия по духу `RefreshToken`
— хранится только SHA-256 хэш, не сырой токен), `PasswordResetTokenService`
(issue/consume, TTL 60 минут, конфигурируемый `app.auth.password-reset-token-ttl-minutes`,
удаление при использовании = невозможность повторного использования).
`AuthService.forgotPassword` **всегда** возвращается успешно вне
зависимости от того, существует ли email — не даёт узнать,
зарегистрирован ли адрес. `AuthService.resetPassword` — хеширует новый
пароль тем же BCrypt-энкодером, что и везде, и **отзывает все
существующие refresh-токены пользователя** (новый метод
`RefreshTokenService.revokeAllForUser`) — если пароль сбросили, старые
сессии на других устройствах не должны оставаться живыми. Новые
эндпоинты: `POST /api/v1/auth/forgot-password`, `POST /api/v1/auth/reset-password`.
Flyway `V18__create_password_reset_token_table.sql`.

Flutter (`user_app`): новый `ForgotPasswordScreen` — два шага на одном
экране (email → код+новый пароль), а не два отдельных роута — реальных
диплинков/magic-link пока нет (нет задеплоенного URL), так что код
вводится вручную, отдельная навигация между шагами не нужна. Ссылка
"Forgot password?" на `LoginScreen`. `AuthApi.forgotPassword`/`resetPassword`,
новый `AuthErrorKey.invalidResetToken`. ARB-ключи en/ru/kk.

Тесты: backend — 3 новых теста в `AuthApiTests` (полный цикл: forgot→
код из перехваченного письма→reset→старый пароль не работает→новый
работает→старая сессия отозвана→код нельзя использовать повторно;
+ email не раскрывает существование аккаунта; + мусорный токен = 401).
Письмо перехватывается тестовым `@TestConfiguration`-бином (`@Primary`
переопределяет `EmailNotificationProvider`), а не парсингом лога —
чище и надёжнее. `./gradlew build` BUILD SUCCESSFUL. Flutter — 4 новых
виджет-теста для `ForgotPasswordScreen` — `user_app` 45/45 (было 41),
`flutter analyze` чисто.

**Живая проверка через curl против реально запущенного backend**: код
сброса извлечён напрямую из серверного лога (`LoggingEmailNotificationProvider`
реально его туда пишет) — неверный код → 401, верный → 200, старый
пароль → 401, новый пароль → 200 с настоящими токенами, повторное
использование кода → 401. Backend остановлен после проверки.

### Текущий статус
Закоммичено и запушено (`649a45b`).

## Production-ready MVP, Phase 1 — Item 3: Notifications (2026-08-21)

**Backend.** `NotificationService` расширен методами для брони:
`sendBookingConfirmedEmail`/`sendBookingCancelledEmail` (клиенту),
`sendNewBookingReceivedEmail`/`sendProviderBookingCancelledEmail`
(владельцу) — все через тот же `EmailNotificationProvider`, других
каналов (Push/SMS) по-прежнему нет — сознательно не заводились
интерфейсы `PushNotificationProvider`/`SmsNotificationProvider` из
диаграммы ТЗ, т.к. реального потребителя для них в проекте нет (прямое
следование принципу ТЗ "не создавай abstraction без consumer" — если
понадобятся, добавляются по образцу `EmailNotificationProvider`).

Новый модуль-компонент `BookingNotificationListener` (в `notifications`)
подписан на уже существующие события `BookingConfirmedEvent`/
`BookingCancelledEvent` (ADR-0002, паблишатся `booking` — та же
инфраструктура, что уже использовал `payments` для авто-возврата при
отмене) и рассылает по 2 письма на каждое событие — клиенту и владельцу
провайдера (email владельца резолвится через `Provider.getOwnerUserId()`
→ `UserRepository`). Слушатель только читает (email по id), поэтому,
в отличие от `BookingCancelledPaymentListener` (который пишет в БД и
требует `@Transactional(propagation = REQUIRES_NEW)` — см. Item 1), ему
эта аннотация не нужна.

Удалён `BookingConfirmedEventListener` — это был явный placeholder
("будет заменён, когда появится реальный consumer"), который просто
логировал факт события; теперь его роль полностью взял на себя
`BookingNotificationListener`.

**Архитектурная находка**: обнаружен и исправлен циклический
Gradle-граф `auth → notifications → booking → auth` (возник из-за
Item 2, где `auth` напрямую дёргал `notifications`, и Item 3, где
`notifications` понадобился доступ к `booking`, который сам зависит от
`auth` через `CurrentUser`). Исправлено не костылём, а архитектурно
правильным способом: доставка password-reset письма переведена с
прямого вызова на публикацию события `PasswordResetRequestedEvent`
(в `auth`, по образцу `BookingConfirmedEvent`) — `auth` больше не
зависит от `notifications` вообще, а `notifications` зависит от `auth`
только за типом события. Итоговый граф без цикла: `notifications→auth`,
`notifications→booking`, `booking→auth`. Как следствие, password reset
теперь тоже идёт через единый ADR-0002 event-паттерн, а не был
единственным исключением с прямым вызовом — это улучшение
консистентности, а не просто обходной путь.

Тесты: общий test-helper `TestNotifications` (по образцу `TestAuth`) —
`@TestConfiguration` с `@Primary`-бином `EmailNotificationProvider`,
перехватывающим ВСЕ письма в список (`CapturedEmails.sent`), а не
только последнее — нужно для проверки, что по одному событию уходит
2 письма разным получателям. `AuthApiTests` перезаведён на этот общий
helper вместо своего локального `FakeEmailConfiguration`. В
`BookingApiTests` — 2 новых теста: подтверждение брони шлёт письма
клиенту ("Booking confirmed") и владельцу ("New booking received");
отмена брони шлёт письма клиенту и владельцу (оба "Booking cancelled",
разный текст). `./gradlew build` — BUILD SUCCESSFUL (весь backend,
все модули).

**Живая проверка через curl против реально запущенного backend**:
полный цикл register(customer+owner)→provider→service→slot→booking→
cancel — в логе сервера подтверждены все 4 письма (2 при подтверждении,
2 при отмене) с правильными получателями, темами и телами, включающими
id брони. Backend остановлен после проверки.

Flutter: изменений не потребовалось — уведомления в этом Item —
исключительно backend-триггерящиеся email, не in-app UI элемент.

### Текущий статус
Закоммичено и запушено (`9c49998`).

## Production-ready MVP, Phase 1 — Item 4: Payment abstraction (2026-08-21)

Анализ по ТЗ ("Минимум: charge, refund, payment status, failure,
idempotency") показал, что `PaymentProvider`/`MockPaymentProvider`
уже закрывают charge/refund/status/failure — но **idempotency
отсутствовала полностью**, и это не абстрактный риск, а реальный,
воспроизводимый баг:

1. **`createPayment` не переживал FAILED-платёж**: `payment.booking_id`
   уникален; при статусе FAILED существующая проверка (`ifPresent`)
   пропускала повторную вставку новой строки — INSERT падал с
   нарушением unique-constraint (500) вместо осмысленного повтора.
   Реальный пользовательский сценарий: карта отклонена → клиент жмёт
   "оплатить" ещё раз → 500 вместо повторной попытки.
2. **`PaymentProvider.refund` не принимал `paymentId`** — то есть у
   real-провайдера не было бы вообще никакого idempotency key на
   стороне refund; сетевой ретрай `refund()` к настоящему Stripe без
   idempotency key рискует **задвоить возврат денег**.
3. Исключение из `paymentProvider.charge(...)` (не false-результат, а
   реально брошенный exception — таймаут/обрыв сети) откатывало всю
   `@Transactional`-транзакцию целиком, включая только что вставленную
   строку `Payment` — то есть даже сам paymentId (idempotency key)
   переставал существовать к моменту ретрая, и следующая попытка
   генерировала НОВЫЙ UUID, что окончательно ломает idempotency-
   контракт с любым реальным провайдером.

**Исправлено, без новых enterprise-абстракций**:
- `createPayment` теперь при существующем FAILED-платеже **переиспользует
  ту же строку** (тот же `paymentId`) вместо вставки новой — SUCCEEDED/
  PENDING/REFUNDED по-прежнему блокируются 409 (для REFUNDED это тоже
  осмысленно: платёж за уже отменённую/возвращённую бронь по факту не
  должен повторно списываться).
- Вызов провайдера обёрнут в try/catch — и false-результат, и
  выброшенное исключение теперь одинаково переводят платёж в FAILED
  (не роняя транзакцию), сохраняя строку/id для следующего ретрая.
- `PaymentProvider.refund` получил параметр `UUID paymentId` (симметрично
  `charge`) — теперь у обеих операций есть стабильный idempotency key,
  который реальная интеграция обязана прокидывать как Stripe
  `idempotencyKey`. Javadoc `PaymentProvider` явно документирует этот
  контракт: "фиксированный paymentId — вот что делает retry безопасным,
  генерация нового id при каждой попытке сводит на нет всю идею".

Тесты: новый shared test-helper `TestPayments` (по образцу `TestAuth`/
`TestNotifications`) — управляемый `@Primary`-бин `PaymentProvider`,
которому можно на лету сказать "следующий charge — отказ" или
"следующий charge — exception" (обычный `MockPaymentProvider` этого не
умеет, он всегда успешен). Два новых теста в `PaymentsApiTests`:
повторная попытка после FAILED переиспользует тот же `paymentId` и
успешно завершается; провайдерское исключение аккуратно переводит
платёж в FAILED вместо 500. `./gradlew build` — BUILD SUCCESSFUL (весь
backend). Живая проверка через curl против реально запущенного backend
подтвердила, что обычный сценарий charge→refund не пострадал от
изменения сигнатуры `refund`.

Flutter: изменений не потребовалось — это внутренняя доработка backend-
контракта, `PaymentsApi`/`PaymentStatusChip` на клиенте ничего не знают
про idempotency key.

### Текущий статус
Закоммичено и запушено (`f2e04d6`). **Phase 1 полностью завершена.**

## Production-ready MVP, Phase 2 — Item 5: Search filters (2026-08-21)

Анализ `SearchService`/`Review` (по требованию ТЗ "проанализировать
repositories/entities/queries перед implementation") показал: `Review`
привязан к `bookingId`, не к `providerId` напрямую — путь до провайдера
идёт через booking → availability_slot → provider, то есть три хопа без
прямого FK. Это ровно тот "дорогостоящий join", о котором явно
предупреждает Item 6 ("не делать join без анализа"). Поэтому rating как
фильтр/сортировка **сознательно вынесен в Item 6** (следующий пункт,
где и будет сделан анализ стоимости), а Item 5 реализован по остальным
пунктам ТЗ: price range, distance, availability, vertical (последний
уже был), плюс сортировки recommended/price asc/price desc/distance.
`SearchSort` задокументирован явно: "RATING не предлагается — это
работа Item 6, не бонус здесь".

**Backend**: `SearchService.search(...)` расширен параметрами
`minPrice`/`maxPrice`/`maxDistanceKm`/`availableOnly`/`sort`
(`SearchSort` enum). Диапазон цен фильтрует по `minPrice` результата
(провайдер без активных услуг никогда не проходит фильтр); `maxDistanceKm`
не бросает ошибку без координат — просто ничего не проходит фильтр
(честно, не выдаёт мусор); `availableOnly` — по `hasOpenAvailability`.
Default-сортировка (`RECOMMENDED`) — старое поведение без изменений.
`SearchController` получил соответствующие `@RequestParam`. 2 новых
теста в `SearchApiTests` (диапазон цен + availableOnly; три варианта
сортировки + maxDistanceKm). `./gradlew build` — BUILD SUCCESSFUL.

**Flutter (`user_app`)**: `DiscoveryQuery` расширен price/distance/
availability/sort полями + `copyWith`; `DiscoveryApi.searchProviders`
прокидывает их в query params (`sort` — обязательно в верхнем регистре,
как ожидает Spring's enum-биндинг). `SearchScreen` получил кнопку
фильтров (`Icons.tune_rounded`, с индикатором активного фильтра —
маленькая точка, тот же принцип "состояние должно быть видно", что и
`FactoryBadge`) рядом с полем поиска, открывающую `_FilterDialog`:
чипы сортировки (`FactoryChip`), два текстовых поля диапазона цен,
два `SwitchListTile` (доступность сегодня / ограничение по
расстоянию) со `Slider` для км. Полностью на `core_ui` design tokens,
без новых компонентов библиотеки. Локализация kk/ru/en (новые ключи
`searchFilters*`/`searchSort*`/`searchFilter*`).

Тесты: новый виджет-тест в `search_screen_test.dart` — открывает
диалог, выбирает "Price: low to high", включает "Available today
only", жмёт Apply, проверяет, что реальный вызов API получил
`sort=PRICE_ASC`/`availableOnly=true`. Обновлены 3 фейковых
`DiscoveryApi`-подкласса в тестах под новую сигнатуру. `flutter
analyze` чисто, `flutter test` 46/46 (было 45), `flutter build web`
успешен.

**Живая проверка**: backend поднят, засеяны 3 провайдера с разными
ценами (8/25/80) через реальный REST API, curl подтвердил фильтр по
диапазону цен, availableOnly и сортировку PRICE_DESC работают
корректно на реальных данных. Затем открыт `flutter run -d chrome`
против реального backend — на реальном экране "Поиск" открыт диалог
фильтров (на русском), выбрана сортировка "Цена: сначала дешевле" +
переключатель "Только с записью на сегодня" → список сократился до 2
салонов, отсортированных по возрастанию цены, кнопка фильтров
показала активный индикатор (скриншоты). Для одобрения тестовых
провайдеров пришлось завести временного ADMIN напрямую в dev Postgres
(bcrypt-хэш сгенерирован тем же приёмом с throwaway javac + jar из
Gradle-кэша, что и раньше в этом проекте) — удалён после проверки.

### Текущий статус
Закоммичено и запушено (`03f69f9`).

## Production-ready MVP, Phase 2 — Item 6: Rating в ranking (2026-08-21)

Продолжение анализа, начатого в Item 5: `Review` привязан к `bookingId`,
до провайдера — три хопа без прямого FK: review → booking →
availability_slot → provider. Проверены индексы на каждом хопе:
`review.booking_id` уникальный индекс (V6), `booking.availability_slot_id`
уникальный индекс (V5), `availability_slot.provider_id` обычный индекс
(V4) — то есть это цепочка индексированных equi-join'ов, а не
неограниченный cross join. Реальная опасность была не в самом SQL, а в
наивной реализации "один запрос агрегации на каждого провайдера в
цикле" (N+1). Поэтому решение: **одна батч-агрегация на весь запрос
поиска**, а не join "в лоб" и не отдельная дорогая абстракция.

**Backend**: новый `ReviewRepository.aggregateRatingsByProviderIds` —
нативный SQL-запрос (`avg(rating)`, `count(*)`, `group by provider_id`)
по списку id провайдеров за один вызов. Обёрнут в
`ReviewSummaryService.summarizeRatings(providerIds)` — единая точка
входа для других модулей (провайдеры без отзывов просто отсутствуют в
результирующей `Map`, не считаются "0 звёзд"). `search` и `favorites`
получили новую Gradle-зависимость на `reviews` (та же "read composition,
не invariant" логика, что и для providers/services/booking).
`SearchDtos.ProviderSearchResult`/`FavoriteDtos.FavoriteProviderResponse`
получили `averageRating`/`reviewCount`. `SearchService.search(...)`
вызывает `summarizeRatings` **один раз на весь батч** кандидатов, до
пагинации/сортировки — не по одному на провайдера. Новый `SearchSort.RATING`
(выше рейтинг — выше в списке; провайдеры без отзывов — в конце, а не
приравнены к нулю/первому месту) и `minRating` фильтр (закрывает и
хвост Item 5 — "rating" как фильтр). `FavoritesService.listFavorites`
получил ту же батч-агрегацию для консистентности карточек между
экранами Search/Home и Favorites.

Тесты: `SearchApiTests` — новый тест с тремя провайдерами (хорошо
оценённый ×2 отзыва, плохо оценённый ×1, без отзывов), проверяет
averageRating/reviewCount в ответе, сортировку RATING (без-отзывов —
последний) и фильтр minRating. `FavoritesApiTests` — новый тест,
подтверждающий рейтинг в избранном. `./gradlew build` — BUILD
SUCCESSFUL (весь backend).

**Flutter (`user_app`)**: `ProviderSearchResult`/`FavoriteProvider`
получили `averageRating`/`reviewCount`. Локальный адаптер `ProviderCard`
прокидывает их в уже существовавший (но никогда не использовавшийся!)
`core_ui.FactoryProviderCard.rating`/`.reviewCount` — компонент был
построен заранее по артефакту дизайн-системы, но не имел реального
потребителя до этого шага. `ProviderDetailScreen` получил
`FactoryRatingLabel` в верхнем ряду бейджей (тоже впервые применённый
где-либо в приложении виджет). `FavoritesScreen`'s `asSearchResult`
адаптер прокидывает рейтинг тоже — карточка не должна выглядеть
по-разному в зависимости от экрана, с которого попала. `SearchScreen`'s
`_FilterDialog` получил чип сортировки "Rating" и переключатель
"Minimum rating" со слайдером (1.0–5.0). Локализация kk/ru/en.

Тесты: 2 новых теста (rating-поля в фикстуре `search_screen_test.dart`
+ ассёрты "4.7"/"(128)"; выбор RATING-сортировки и minRating в
диалоге фильтров доходит до реального вызова API), 1 новый ассёрт в
`provider_detail_screen_test.dart` (рейтинг отображается на detail-
экране). `flutter analyze` чисто, `flutter test` 47/47 (было 46),
`flutter build web` успешен.

**Живая проверка**: backend поднят, засеян провайдер с 3 реальными
завершёнными+оценёнными бронированиями (5, 4, 3 звезды → среднее 4.0,
3 отзыва) через настоящий REST API, curl подтвердил `averageRating: 4,
reviewCount: 3` в ответе поиска. Открыт `flutter run -d chrome` —
карточка в результатах поиска показала "★ 4.0 (3) · beauty", и на
detail-экране того же провайдера — "★ 4.0 (3)" рядом с бейджем Beauty
(скриншоты). Для одобрения провайдера снова понадобился временный
ADMIN в dev Postgres (тот же bcrypt-приём) — удалён после проверки.

### Текущий статус
Закоммичено и запушено (`64856cc`). **Phase 2 полностью завершена.**

## Production-ready MVP, Phase 3 — Item 7: Recurring schedule (2026-08-21/22)

**Backend**: новый `RecurringScheduleService` (в модуле `booking`, рядом с
`AvailabilitySlot`) генерирует реальные слоты из недельного паттерна
(дни недели + время начала/окончания + длительность + перерыв между
слотами) на диапазон дат, с пропуском праздников. Ключевые решения:
- **Timezone обязателен явно** (`zoneId`, IANA или fixed-offset строка
  типа "+06:00") — у `Provider` нет своего поля timezone (в проекте
  такого не было нужно раньше), и молча брать зону сервера означало бы
  генерировать слоты не в то время суток для владельца в другом
  часовом поясе.
- **Конфликты с уже существующими слотами (любой статус) — пропускаются,
  не перезаписываются** — прямое требование ТЗ "не удалять существующие
  slots без явного действия". Один batch-запрос
  (`findByProviderIdAndStartsAtLessThanAndEndsAtGreaterThan`) на весь
  диапазон дат сразу, не по одному на кандидата — тот же принцип, что
  и `ReviewSummaryService` из Item 6.
- **Побочный эффект этого же conflict-skip: защита от duplicate
  generation** — повторный запуск того же расписания находит уже
  созданные слоты как конфликты и ничего не дублирует.
- Валидация: хотя бы один день недели, startTime < endTime,
  положительная длительность, break ≥ 0, диапазон дат не более 92 дней
  (реальный guard от случайного ввода диапазона в годы, не искусственный
  enterprise-лимит).
- Новый endpoint `POST /api/v1/providers/{id}/availability-slots/recurring`
  (owner-only, `ProviderOwnership`), возвращает `{created: [...],
  skippedConflictCount}`.

Тесты: новый `RecurringScheduleApiTests` — генерация слотов на
выбранные дни недели + повторный запуск не создаёт дублей (0 created,
все skipped), пропуск праздника, валидация startTime≥endTime → 400,
ownership → 403. `./gradlew build` — BUILD SUCCESSFUL (весь backend).

**Flutter (`business_admin`)**: новый `RecurringScheduleDialog` —
чипы дней недели (`FactoryChip`), пикеры времени начала/окончания,
поля длительности/перерыва, пикеры диапазона дат, список праздников
(добавление через date picker, удаление через `InputChip`). Кнопка
"Повторяющееся расписание" добавлена рядом с "Добавить" в разделе
"Доступное время" `SalonDetailScreen`. `SalonAdminApi.createRecurringSchedule`
форматирует запрос под backend (дни недели как "MONDAY" и т.д., время/
даты как ISO-строки, зона — текущий fixed-offset устройства). Полная
локализация kk/ru/en (новые ключи `recurringSchedule*`/`weekday*`).

Тесты: новый тест в `salon_detail_screen_test.dart` — открытие диалога,
переключение чипа дня, блокировка отправки без заполненных полей
(валидация на клиенте, API не вызывается). `flutter analyze` чисто,
`flutter test` 19/19 (было 18), `flutter build web` успешен.

**Живая проверка**: backend поднят, зарегистрирован реальный owner с
салоном через настоящий REST API. Открыт `flutter run -d chrome`,
выполнен полный вход через форму логина, переход в салон, открытие
диалога "Повторяющееся расписание", выбор Пн+Ср через реальные time/
date picker'ы (10:00–18:00, 30 мин слот, 10 мин перерыв, диапазон
2026-08-24…2026-09-06), отправка. Snackbar показал "Создано слотов: 48,
пропущено: 0" — арифметика сошлась (4 подходящих дня × 12 слотов/день
при 8-часовом окне с 40-минутным циклом). Список "Доступное время"
после обновления показал все 48 слотов сгруппированными по датам (авг
24/26/31, сен 2) со временем каждые 40 минут (скриншоты). Столкнулся
с известной проблемой захвата фокуса окна на этой машине (терминал
самого Claude Code перехватывал foreground) — решено принудительной
минимизацией текущего foreground-окна перед активацией целевого Chrome.

### Текущий статус
Закоммичено и запушено (`69bbffb`).

## Production-ready MVP, Phase 3 — Item 8: Portfolio fullscreen viewer (2026-08-22)

Новый `PortfolioFullscreenViewer` в `user_app` (модуль `beauty`) —
переиспользует те же `PortfolioItem`/`imageUrl`, что уже выдаёт
`MasterPortfolioScreen`'s grid (backend storage API не тронут вообще,
как явно требует ТЗ). `PageView.builder` с нативным swipe-жестом +
кнопки next/previous (`chevron_left`/`chevron_right`, скрываются на
первом/последнем фото — не просто disabled, а honestly отсутствуют,
раз действие невозможно), кнопка закрытия (X), счётчик "N of M",
подпись снизу (если есть). Каждое фото — `Image.network` с
`loadingBuilder` (спиннер — не показывать пустой экран при загрузке)
и `errorBuilder` (иконка "битое изображение" + текст, никогда не
молчаливый сбой). `InteractiveViewer` обёрткой — pinch-zoom не был
явным требованием ТЗ, но достаётся почти бесплатно и уместен для
fullscreen-просмотра фото. Заодно и сам grid в `MasterPortfolioScreen`
получил `loadingBuilder` (маленькое, тесно связанное улучшение) —
раньше во время загрузки превью просто ничего не показывал.

Локализация kk/ru/en (новые ключи `portfolioViewer*`,
`errorPortfolioImageLoadFailed`).

Тесты: новый `portfolio_fullscreen_viewer_test.dart` (4 теста) — тап
по фото открывает viewer с правильным индексом; next/previous
кнопки переключают и корректно скрываются на границах; swipe
(`tester.drag` по `PageView`) листает; кнопка закрытия возвращает на
grid. `flutter analyze` чисто, `flutter test` 51/51 (было 47),
`flutter build web` успешен.

**Живая проверка**: backend поднят, найден в dev Postgres реально
существующий мастер "Jamie Stylist" с 2 портфолио-фото на реальных
внешних URL (picsum.photos — не фейковые тестовые ссылки). После
одобрения провайдера временным ADMIN, в `flutter run -d chrome`:
поиск салона → карточка мастера с иконкой портфолио → grid с двумя
реальными фото → тап по первому открывает fullscreen с "1 из 2" +
подпись "Balayage look" + только кнопка "вперёд" (это первое фото) →
клик "вперёд" переключает на "2 из 2" + подпись "Classic bob" +
кнопка сменилась на "назад" (это последнее фото) — оба реальных фото
отрендерились корректно (скриншоты). По ходу проверки повторно
столкнулся с перехватом фокуса окна терминалом Claude Code между
отдельными вызовами инструмента — решено выполнением всей
последовательности клик→ожидание→скриншот **одним** PowerShell-вызовом
с принудительной пере-фокусировкой перед каждым шагом внутри него,
а не раздельными вызовами (между которыми терминал успевает
перехватить фокус) — более надёжный вариант уже известного приёма,
стоит использовать именно так в следующий раз.

### Текущий статус
Закоммичено и запушено (`8feacba`). **Phase 3 полностью завершена.**

## Production-ready MVP, Phase 4 — Accessibility (2026-08-22)

Начало Phase 4 (UI/accessibility/localization/branding/platform
validation) с конкретного, уже выявленного пункта ТЗ: хардкод
английской семантики "Add to favorites"/"Remove from favorites".

Анализ показал, что реальная проблема шире одной строки:
- `user_app`'s `FavoriteButton` (реально используемая кнопка-сердце на
  `ProviderDetailScreen` и др.) — обычный `IconButton` **вообще без**
  `tooltip`/`Semantics` — скринридер объявлял бы её просто как
  безымянную кнопку, ни на английском, ни на любом другом языке.
  Добавлены `tooltip: l10n.favoriteAddTooltip`/`favoriteRemoveTooltip`.
- `core_ui`'s `FactoryProviderCard._FavoriteButton` — тот самый хардкод
  из ТЗ. Поскольку `core_ui` — общий пакет без доступа к
  app-level `AppLocalizations`, добавлены параметры
  `favoriteAddSemanticLabel`/`favoriteRemoveSemanticLabel` (со
  english-fallback по умолчанию для обратной совместимости — сейчас
  этот путь виджета вообще не используется ни в одном реальном экране,
  но остаётся частью публичной библиотеки компонентов).
- При написании теста на новые метки найдена **более серьёзная,
  независимая a11y-проблема**: `_FavoriteButton`'s `Semantics` не имел
  `container: true`, из-за чего его label сливался с семантикой всей
  карточки (InkWell) — скринридер получил бы один слипшийся узел
  "Add to favorites\nAigerim Beauty Studio" вместо отдельного
  доступного элемента управления, вложенного в область тапа карточки.
  Добавлен `container: true` — теперь у кнопки избранного собственный
  узел семантики.
- Заодно найдена и исправлена такая же проблема в `FactoryRatingLabel`
  (используется в `ProviderDetailScreen`/`ProviderCard` с Item 6) —
  хардкод "out of 5"/"reviews". Добавлен параметр `semanticLabel`
  (caller-supplied override), обе живые точки использования в
  `user_app` теперь передают локализованный текст
  (`ratingSemanticLabel`/`ratingSemanticLabelWithReviews`, с
  корректной плюрализацией ru/kk через ICU `{count, plural, ...}`).
- Звёздный picker в диалоге "оставить отзыв" (`review_section.dart`) —
  5 `IconButton` вообще без подписи ни на каком языке. Добавлен
  `tooltip: l10n.starRatingSemanticLabel(i + 1)` ("Rate 4 stars" и
  т.п., с плюрализацией).

Новые ARB-ключи (`favoriteAddTooltip`/`favoriteRemoveTooltip`,
`ratingSemanticLabel`/`ratingSemanticLabelWithReviews`,
`starRatingSemanticLabel`) — en/ru/kk, ru с полной плюрализацией
(one/few/many/other), kk только с `other` (соответствует CLDR-правилам
для казахского и уже устоявшейся практике в этом проекте, см.
`homeAvailabilityHero`).

Тесты: `core_ui` — новый тест, подтверждающий, что кастомная метка
доходит до `Semantics.label` (этот тест и обнаружил баг с `container:
true` — до фикса падал на слипшемся тексте). `user_app` — 2 из 3 тестов
`favorite_button_test.dart` использовали `const MaterialApp(home:
...)` без `localizationsDelegates` — упали сразу же, как только кнопка
стала звать `AppLocalizations.of(context)!` (тот самый паттерн, что
уже раз десять встречался в этом проекте) — исправлено, плюс добавлены
прямые ассёрты на `find.byTooltip(...)` в обоих файлах
(`favorite_button_test.dart`, `review_section_test.dart`). `core_ui`
23/23 (+1), `user_app` 51/51 (то же число тестов, 2 переписаны + 2
новых ассёрта), `business_admin` `flutter analyze` чисто (тоже зависит
от `core_ui`, изменения обратно совместимы), `flutter build web`
успешен в `user_app`.

### Текущий статус
Закоммичено и запушено (`c91ccfd`). От `master` создана и запушена
ветка `test` (`origin/test`, тот же коммит) — по просьбе пользователя,
дальнейшая работа Phase 4 ведётся в ней.

По ходу обнаружена и исправлена повторно всплывшая проблема окружения:
Android Studio, открытая в корне репозитория, показывала модули `app`/
`zairo_android` с красными крестиками — протухшие ссылки в локальном
(негитовом) `.idea/workspace.xml` на давно удалённый дублирующий
Android-проект (см. `zairo_android_project_fix` в памяти). Исправлено
удалением `C:\app\zairo\.idea` (полностью регенерируемый кэш) — далее
Android Studio открывается не на корне репозитория, а на `apps/user_app`
или `apps/business_admin` напрямую.

## Production-ready MVP, Phase 4 — UI-аудит, локализация, брендинг (2026-08-24)

Продолжение Phase 4 после accessibility-прохода: UI/design-system-аудит
обоих Flutter-приложений, техническая ревизия казахской локализации,
подключение реального логотипа/брендинга.

### UI/design-system аудит

Два параллельных read-only аудита (по одному на приложение) против
токенов `core_ui` (`FactoryColors`, `FactorySpacing`, `FactoryEmptyState`/
`FactoryErrorState`, `FactorySkeleton`). Найденное и исправленное:

**`user_app`:**
- `FavoriteButton` — заливка сердца хардкодила `Colors.red` вместо
  `context.factoryColors.error` (тот самый токен, который уже
  использует `core_ui`'s `_FavoriteButton` для того же состояния) — не
  адаптировалось бы к тёмной теме. Исправлено.
- `MasterPortfolioScreen` — пустое состояние и состояние ошибки были
  голым `Center(child: Text(...))`, в отличие от всех остальных
  списочных/детальных экранов приложения, которые используют
  `FactoryEmptyState`/`FactoryErrorState`. Добавлен новый ключ
  `portfolioEmptyTitle` (en/ru/kk) под уже существующий
  `portfolioEmptyMessage`; error-состояние получило `onRetry`,
  инвалидирующий `masterPortfolioProvider`.
- `ProfileScreen` — то же самое для error-состояния (`errorProfileGeneric`
  уже использовался с `FactoryErrorState` в `FavoritesScreen` — здесь
  просто не был применён тот же паттерн).
- Точечная зачистка «магических» отступов, не попадающих в шкалу
  `FactorySpacing` (4/8/12/16/20/24/32/40/48), на login/register/forgot-
  password экранах, `home_screen.dart`, `review_section.dart` — везде
  заменено на именованные токены. `FactorySkeleton` в приложении нигде
  не используется (подтверждено), так что везде используемый голый
  `CircularProgressIndicator()` — это установившийся паттерн, а не
  отклонение, трогать не стал.

**`business_admin`:**
- `ManageMasterServicesDialog` — самая существенная находка: диалог
  жёстко фиксировал `SizedBox(width: 360)` вместо auto-sizing, которым
  пользуются все остальные диалоги приложения. На Android-экране шириной
  360dp (частый класс разрешений) стандартные отступы `AlertDialog`
  оставляют ~232dp полезной ширины — фиксированные 360dp гарантированно
  вылезли бы за экран. Исправлено удалением `SizedBox`.
- Механическая зачистка raw-чисел, дублирующих значения из
  `FactorySpacing` (`EdgeInsets.all(24)`, `top: 8`, `vertical: 8`,
  `16`/`12` на login/register) в 8 файлах — та же логика, что и в
  `user_app`. `FactoryEmptyState`/`FactoryErrorState` уже применяются
  корректно там, где нужны (полноэкранные состояния в
  `moderation_screen`/`dashboard_screen`); компактные inline-заглушки
  внутри секций `salon_detail_screen.dart` (services/slots/masters/
  bookings) осознанно НЕ заменены — `FactoryEmptyState` — это тяжёлый
  icon+title+message блок для полноэкранных состояний, а не для
  подсекции карточки, замена была бы избыточной. Нет ни одного
  хардкоженного `Colors.*` во всём приложении.

Тесты: после правок 3 теста в `user_app` упали, так как
`FactoryEmptyState`/цвет из `context.factoryColors` требуют
`theme: factoryLightTheme()` в тестовом `MaterialApp` (тот самый паттерн
отсутствующих делегатов/темы, что и раньше) — добавлено в
`master_portfolio_screen_test.dart` и `favorite_button_test.dart` (все 3
теста файла, включая logged-out ветку — она пушит `LoginScreen`, который
после следующего пункта тоже стал зависеть от темы).

### Локализация — техническая ревизия казахского

Скрипт сравнил каждый ключ `app_kk.arb` с `app_ru.arb`/`app_en.arb` в
обоих приложениях (полнота ключей подтверждена — пропусков нет).
Результат — `docs/NEEDS_NATIVE_REVIEW.md`: список ключей, где kk-значение
дословно совпадает с ru (вероятные заимствования вроде «профиль»,
«рейтинг», «портфолио» — почти наверняка нормально для казахского, но
не проверено носителем) плюс один более уверенный кандидат —
`weekdayWed` в `business_admin` («Ср» в kk совпадает с ru побуквенно, в
отличие от всех остальных 6 дней недели, которые различаются корректно).
Ничего в ARB-файлах не менялось — по инструкции ТЗ правильнее пометить
для ревью носителем, чем самому придумывать перевод.

### Брендинг — логотип

Нашёлся уже опубликованный ранее в этой сессии артефакт "Factory
Logomark" (design artifact, не подключён ранее к реальным ассетам) —
"Module Mark": три закрашенных блока (Core + первая живая вертикаль
Beauty, в золотом accent) и четвёртый блок нарисован открытым/
пунктирным — незанятый слот под следующую вертикаль. Полностью собран
из уже существующих токенов `core_ui` (primaryStrong/accent/primary/
borderStrong), ничего нового в палитру не добавлено. Подключено:

- `packages/core_ui/lib/src/widgets/factory_logomark.dart` (новый) —
  `FactoryLogomark` виджет, `CustomPainter`, рисует марку через
  `context.factoryColors` (адаптируется к тёмной теме автоматически).
  Ниже ~32px четвёртый блок автоматически переключается с пунктирного
  на плоский «тихий» — то же правило, что и в самом артефакте
  (`dashedFourthBlock` параметр для ручного оverride). Добавлен в
  `login_screen.dart` обоих приложений (только сама марка, без текста
  "Factory" — рабочее кодовое имя не должно светиться в реальном UI,
  см. `[[factory_platform_pivot]]`).
- Реальные PNG-иконки: одноразовый генератор
  (`test/_tool/generate_app_icon.dart`, запущен через `flutter test` с
  `tester.runAsync` — прямые `dart:ui` Canvas/PictureRecorder вызовы не
  завершаются без него, зависают на fake-time зоне тестов; удалён после
  использования) отрисовал master-иконки 1024×1024 под каждое
  приложение (`user_app`: тёмно-зелёный фон, `business_admin`: зелёный
  фон посветлее — чтобы иконки различались на рабочем столе). Дальше
  `flutter_launcher_icons` (новая dev-зависимость обоих приложений)
  сгенерировал полный набор: Android `mipmap-*/launcher_icon.png` +
  `AndroidManifest.xml` `android:icon` перепривязан, iOS
  `AppIcon.appiconset` (не блокер по ТЗ, но раз папка уже есть — сделано
  заодно, `remove_alpha_ios: true` для App Store совместимости), web
  `favicon.png`/`icons/Icon-*.png`/`manifest.json`. Старые дефолтные
  `ic_launcher.png` удалены как осиротевшие.

Найдена и исправлена попутная проблема окружения: `dart run
flutter_launcher_icons` падал с "Could not find pubspec.yaml" на
`path_provider_linux`/`path_provider_windows` в pub-кэше — оказались
пустыми (повреждённая распаковка, не связана с AVG/SSL). Исправлено
удалением повреждённых директорий из
`~/AppData/Local/Pub/Cache/hosted/pub.dev/` и повторным `flutter pub get`.

Тесты: `core_ui` 24/24 (+1, smoke-тест `FactoryLogomark` на обоих
size-вариантах), `user_app` 51/51, `business_admin` 19/19,
`flutter analyze` чисто на всех трёх. `flutter build web` и `flutter
build apk --debug` успешны в обоих приложениях (Android APK — то самое
"Android+Web platform validation" из ТЗ Phase 4; предупреждение про
`file_picker`/Kotlin Gradle Plugin в `business_admin` — известная,
задокументированная в памяти особенность, не новая регрессия).

### Текущий статус
Закоммичено и запушено в `test` (`5301643`).

## Фикс регистрации на Android-эмуляторе (2026-08-25)

Пользователь сообщил, что регистрация падает с ошибкой на Android-
эмуляторе, хотя backend поднят и `/actuator/health` отвечает `UP`.
Найдены две накладывающиеся причины:

1. `baseUrl` в обоих приложениях был жёстко прописан как
   `http://localhost:8080/api/v1` (`environment.dart`) — внутри
   Android-эмулятора `localhost` указывает на сам эмулятор, а не на
   хост-машину; нужен специальный алиас `10.0.2.2`.
2. Даже после смены хоста трафик всё равно был бы заблокирован: Android
   по умолчанию запрещает cleartext (незашифрованный `http://`) для
   `targetSdk` 28+, а backend работает по обычному HTTP (HTTPS-окружения
   пока нет — см. комментарий в `environment.dart`).

Исправлено в обоих приложениях:
- `lib/core/constants/environment.dart` — `appNetworkConfig`/
  `adminNetworkConfig` из `const` превращены в геттеры, которые
  определяют платформу (`kIsWeb`/`Platform.isAndroid`) и подставляют
  `10.0.2.2` только на Android, иначе `localhost`. Физическое
  устройство (не эмулятор) этим не покрывается — там нужен реальный
  LAN IP хоста, задокументировано в комментарии.
- `android/app/src/debug/AndroidManifest.xml` — добавлен
  `<application android:usesCleartextTraffic="true"/>`, смёрживается
  только в debug-сборку (Android Gradle manifest merger объединяет
  `<application>` из debug/main без конфликта) — релизная сборка
  cleartext не получает.

Тесты: `flutter analyze` чисто в обоих приложениях, `user_app` 51/51,
`business_admin` 19/19, `flutter build apk --debug` успешен в обоих
(манифест смёржился без ошибок). Живая проверка: пользователь
перезапустил приложение в эмуляторе (native-манифест не подхватывается
hot reload/restart, нужен полный переустанов) — регистрация заработала.

### Текущий статус
Закоммичено и запушено в `test` (`70d5869`).

## Экран настроек в business_admin (2026-08-25)

Пользователь тестировал `business_admin` и заметил, что интерфейс
только на английском, без возможности сменить язык — в отличие от
`user_app`, у `business_admin` вообще не было экрана настроек, хотя
переводы на ru/kk в его собственных ARB-файлах уже полные (использовались
для recurring schedule, модерации и т.д.). Тёмная тема тоже жёстко
зависела только от системной без переключателя.

По просьбе пользователя добавлен полный паритет с `user_app`:
- `lib/app/locale/locale_controller.dart`, `lib/app/theme/theme_provider.dart`
  (новые) — точная копия паттерна `user_app` (язык персистится через
  `secureStorageServiceProvider`, тема — нет, как и в `user_app`).
- `lib/app/app.dart` — `BusinessAdminApp` стал `ConsumerWidget`,
  `MaterialApp` получил `themeMode`/`locale` из этих провайдеров.
- `lib/features/settings/presentation/screens/settings_screen.dart`
  (новый) — переключатель тёмной темы + пикер языка (System default/
  English/Русский/Қазақша), дословная копия `user_app`'s `SettingsScreen`.
- Кнопка-шестерёнка добавлена в `AppBar` обоих корневых экранов
  (`DashboardScreen` для owner, `ModerationScreen` для admin — оба ведут
  на один и тот же `SettingsScreen`), рядом с уже существующей кнопкой
  logout.
- Новые ARB-ключи (en/ru/kk): `settingsButtonTooltip`, `settingsTitle`,
  `darkModeTitle`, `darkModeSubtitle`, `themeModeSystem/Light/Dark`,
  `languageSectionTitle`, `languageSystemDefault` — значения взяты один в
  один из `user_app`.

Тесты: новый `settings_screen_test.dart` (2 теста, зеркалит `user_app`'s
версию) — дефолт на системный язык + переключение на казахский с
персистентностью, и сброс на "как в системе". `flutter analyze` чисто,
`flutter test` 21/21 (было 19), `flutter build web` успешен.

### Текущий статус
Закоммичено и запушено в `test` (`1141e88`).

Пользователь заметил несостыковку: кнопка настроек была добавлена
только на `DashboardScreen`/`ModerationScreen` — оба доступны лишь
после входа, а `AuthGate` без логина показывает только `LoginScreen`
без какого-либо шелла вокруг. В `user_app` язык можно менять до входа,
потому что там Profile-вкладка — часть нижней навигации, видимой
всегда (даже незалогиненному пользователю), а не потому что кнопка
стоит на `LoginScreen`/`RegisterScreen` (её там и в `user_app` тоже
нет). Раз в `business_admin` нет аналогичного "всегда видимого"
пре-логин экрана, кнопка настроек добавлена прямо на `LoginScreen` (не
на Register — как и в `user_app`, там её тоже нет) — это структурный
аналог user_app's Profile-таба для этого приложения. `flutter analyze`
чисто, `flutter test` 21/21.

### Текущий статус
Закоммичено и запушено в `test` (`811ea4a`).

## OpenAPI/Swagger документация всего backend (2026-08-25)

По отдельному запросу пользователя — полноценная production-quality
Swagger/OpenAPI документация на весь REST API backend'а, с локализацией
en/ru/kk. Не точечные `@Operation` на паре контроллеров, а системная
документация: все 14 контроллеров / 57 операций / 42 path.

### Аудит перед внедрением
Сначала полный анализ кодовой базы (см. переписку) выявил:
- **Нет Spring Security** — лёгкий кастомный `JwtAuthFilter` + ручные
  проверки `CurrentUser.require*` по каждому методу отдельно (не единый
  security-конфиг). Из 57 операций 18 реально защищены токеном — список
  вычислен вручную по коду.
- **Нет global exception handler и единой модели ошибок** — только
  дефолтный Spring Boot `{timestamp,status,error,path}`, без `message`.
- **Ноль bean-validation аннотаций** во всём проекте — невалидный
  `POST /auth/register` реально падал в 500 вместо 400 (проверено curl'ом
  на живом backend).
- Пагинации нигде нет (все списки — плоский `List<T>`).
- Найдены недокументированные API: `POST/GET /users` (без аутентификации
  вообще), `PATCH /providers/{id}/status` (admin-only).

Пользователь подтвердил (после явного вопроса) добавить минимальный слой
validation + global exception handler — это исправление реального бага
(500→400), а не смена бизнес-логики.

### Phase 1 — фундамент
- `springdoc-openapi-starter-webmvc-ui:3.0.0` (только `platform-api`,
  проверено резолвом — совместимо со Spring Boot 4.1/Spring 7).
- `ApiError`/`GlobalExceptionHandler` (`platform-api/.../error/`) —
  единая модель ошибок для вообще всех исключений в проекте, включая уже
  существующие (`EmailAlreadyRegisteredException` и т.п.) — работает
  "из коробки" без правок в каждом модуле.
- `jakarta.validation`-аннотации на все request DTO 7 модулей —
  **обоснованные кодом**: длины полей — из SQL-миграций (`varchar(255)`
  и т.д.), `price >= 0` — из уже существующего `Money.requireNonNegative()`,
  `rating 1-5` — из уже существующей проверки в `ReviewService`. Ничего
  не выдумано.
- `OpenApiConfig` — title/description/servers (из `application.yml`)/JWT
  Bearer security scheme/14 тегов по модулям/6 переиспользуемых
  компонентов ошибок (`BadRequest`/`Unauthorized`/`Forbidden`/`NotFound`/
  `Conflict`/`ServerError`, через `ModelConverters` + `$ref`).
- `spring.web.locale: en` — иначе bean-validation сообщения шли на
  русском (JVM брала локаль ОС), что не билось с остальным English-контрактом
  ошибок.

**Живая проверка**: `POST /auth/register {}` — было 500, стало
`400 {"errors":{"email":"must not be blank",...}}`. `swagger-ui/index.html`,
`/v3/api-docs`, `/v3/api-docs.yaml` — все 200, JSON валиден.

### Phase 2 — документация каждого endpoint'а
`@Operation`/`@ApiResponse`/`@Parameter`/`@Schema(example=...)` на все 14
контроллеров и их DTO, по модулям (Auth → Users → Providers → Services →
Availability → Bookings → Payments → Reviews → Favorites → Search →
Storage → Country → Beauty Masters → Beauty Bookings), с промежуточными
компиляциями каждые 2-6 контроллеров. Паттерн: `ref="BadRequest"` для
типовых 400, инлайн `@ApiResponse` с текстом через `@Schema(ref=
"#/components/schemas/ApiError")` там, где причина специфична для
конкретного endpoint'а (иначе OpenAPI молча игнорирует `description`
рядом с `$ref` — сиблинги `$ref` не учитываются спекой). Multipart upload
(`StorageController`) задокументирован через `@RequestBody(content=
@Content(mediaType=MULTIPART_FORM_DATA_VALUE, schema=@Schema(type=
"string", format="binary")))`.

Добавлен `OpenApiTests.java` — регрессионный тест: у каждой операции
обязан быть непустой `summary`, иначе билд падает; плюс проверка
`/v3/api-docs`, `/v3/api-docs.yaml`, `/swagger-ui/index.html`.

**Живая проверка**: полный curl-сценарий Register→Login→/auth/me через
реальный backend/Postgres; Swagger UI открыт в Chrome, `Try it out`
подтверждён визуально (скриншоты). Найден и исправлен свой же баг
конфига: `springdoc.swagger-ui.path: /swagger-ui/index.html` дублирует
путь (`/swagger-ui/swagger-ui/index.html`, 404/зависшая загрузка) —
убрано, дефолтный путь и так `/swagger-ui/index.html`.

### Phase 3 — локализация en/ru/kk
Архитектура: `GroupedOpenApi` (springdoc) — 3 бина (`en`/`ru`/`kk`),
каждый покрывает `/**`, `ru`/`kk` несут `LocalizingOpenApiCustomizer`.
Тексты в аннотациях (`@Operation`/`@Tag`/`@Parameter`/`@ApiResponse`)
остаются английскими навсегда — единственный источник истины; customizer
после сборки документа проходит по всему дереву `OpenAPI` (info, tags,
securitySchemes, components.responses, каждая operation: summary/
description/parameters/responses) и подменяет текст через таблицу
переводов. Таблицы — JSON (не `.properties`: значения — многострочный
текст с markdown/бэктиками, `.properties`-экранирование для этого
хрупкое), ключ — сама английская строка (gettext-стиль), не выдуманный
короткий ключ — под несовпавшую строку просто остаётся английский текст,
а не ошибка сборки. `docs/openapi/translations_ru.json`,
`translations_kk.json` — по 222 строки каждый (summary/description
операций, tag-описания, parameter-описания, response-описания, включая
6 переиспользуемых компонентов ошибок и info/security-scheme текст).
`@Schema`-описания на уровне полей DTO осознанно оставлены
английскими — иначе объём перевода утраивается, а это не то, что
разработчик читает в первую очередь.

Swagger UI подхватывает доп. группы автоматически — верхний правый
"Servers" превращается в "Select a definition" пикер (`English`/
`Русский`/`Қазақша`), без отдельной фронтенд-работы. `/v3/api-docs/ru`,
`/v3/api-docs/kk`, а с явно добавленной `en`-группой (иначе дефолтный
документ не появлялся в пикере вообще) — и `/v3/api-docs/en`.

**Два реальных бага найдены и исправлены по ходу**:
1. `info.description`/`securitySchemes.description` не переводились —
   `springdoc.cache.disabled: true` не помогло (неверная гипотеза),
   реальная причина другая — см. следующий пункт.
2. **Главный баг**: Java text block (`"""..."""`) при компиляции убирает
   общий отступ и схлопывает `\` + перенос строки — но мой Python-скрипт
   извлечения текста для перевода взял **сырой** текст между `"""` с
   исходными отступами и обратными слэшами. Ключи в JSON не совпадали с
   реальными runtime-строками ни на йоту → `translate()` тихо возвращал
   английский текст как есть (fallback), без ошибки — отсюда и казалось,
   что "часть полей не переводится". Исправлено: живой EN `/v3/api-docs`
   стал источником канонических ключей — все 222 строки сопоставлены с
   существующими (уже написанными) переводами через сравнение с
   нормализацией (схлопывание `\`+перенос, как это делает javac), затем
   значения-переводы для текстовых блоков дополнительно очищены от тех
   же артефактов (в исходных ru/kk файлах перевод тоже был скопирован
   с лишними `\` и отступами). Это ценный урок: **никогда не парсить
   Java text blocks регуляркой без явной репликации JLS 3.10.6
   (индентация) и обработки `\`-продолжений** — либо тянуть канонические
   строки из уже скомпилированного/сериализованного вывода.

**Живая проверка**: `/v3/api-docs`, `/v3/api-docs/ru`, `/v3/api-docs/kk`
сверены по всем типам полей (info/tag/securityScheme/operation/parameter/
component-response) — все переведены корректно, кроме английского
(намеренно эталон). Swagger UI открыт в Chrome — пикер языка со всеми
тремя опциями, переключение на Русский и Қазақша визуально подтверждено
(скриншоты), верхняя часть страницы и весь список endpoint'ов
переведены.

### Итог
`./gradlew test` — зелёный после каждой фазы. 57 операций, 42 path, 14
тегов, 3 языка, единая модель ошибок, JWT Bearer auth, 222×2 строки
перевода. `swagger.enabled` через `springdoc.swagger-ui.enabled=false`/
`springdoc.api-docs.enabled=false` (env vars) для прод.

### Текущий статус
Закоммичено и запушено в `test` (`1b32755`).

## Закрытие дыр в авторизации (2026-08-25)

По итогам OpenAPI-аудита нашлось 6 категорий реально незащищённых
эндпоинтов (авторизация в бэкенде — не Spring Security, а ручные
проверки `CurrentUser.require*`/`ProviderOwnership.requireOwner` по
каждому методу контроллера, так что "что защищено" нельзя было прочитать
из одного места — только собрать по гвоздикам). Пользователь явно
выбрал приоритет: **"чинить дыры"**.

**Что было открыто и что исправлено**:
1. `POST /api/v1/bookings` — теперь только `CurrentUser.requireUserId`
   == `request.userId()`, иначе 403.
2. `POST /api/v1/beauty/bookings` — то же самое.
3. `GET /api/v1/users/{userId}/bookings` — только сам пользователь.
4. `GET /api/v1/providers/{providerId}/bookings` — только владелец
   провайдера (`ProviderOwnership.requireOwner`, добавлено внедрение
   `ProviderOwnership` в `BookingController` — модуль `booking` уже
   зависел от `providers`, так что новых Gradle-зависимостей не
   потребовалось).
5. `POST/DELETE/GET /api/v1/users/{userId}/favorites/{providerId}`,
   `GET /api/v1/users/{userId}/favorites` — только сам пользователь.
   Модулю `favorites` добавлена зависимость `implementation(project(":auth"))`.
6. `POST /api/v1/uploads` — любой аутентифицированный вызывающий
   (`CurrentUser.requireUserId`, результат отбрасывается). Модулю
   `storage` добавлена зависимость на `auth`.
7. `POST /api/v1/users` и `GET /api/v1/users` — только ADMIN.

**Архитектурная особенность п.7**: модуль `users` не может зависеть от
`auth` — `auth` уже зависит от `users` (нужен `UserRole`), обратная
зависимость дала бы Gradle-цикл. Решение: в `UserController` локально
продублирован тот же приём, что уже применялся для OpenAPI `$ref`
через строку — вместо `CurrentUser.requireAdmin` читаем тот же
request-атрибут (`"auth.role"`, то же имя, что `JwtAuthFilter.ROLE_ATTRIBUTE`)
напрямую, с комментарием, почему. Это единственное место, где проверка
не переиспользует существующий класс `CurrentUser`.

**Безопасность фронтенда проверена ДО правки бэкенда**: сначала вручную
подтверждено, что `core_network`'s Dio-интерцептор автоматически
прикладывает `Authorization: Bearer` к каждому запросу, когда токен
есть — значит оба Flutter-приложения технически готовы отправлять
токен. Затем fork-субагент прочитал реальный Dart-код обоих приложений
и подтвердил по всем 6 категориям: экран/кнопка либо гейтится
`currentUser == null` до вызова эндпоинта, либо единственная точка
вызова уже требует владельца/себя (RISK не найден нигде) — это дало
уверенность, что ужесточение бэкенда не сломает ни одно реальное
приложение.

**Тесты**: правка сломала 8 файлов интеграционных тестов, которые
создавали "клиента" через сырой (беспарольный) `POST /api/v1/users`
и затем дёргали теперь-защищённые эндпоинты без токена вообще —
`FavoritesApiTests`, `BookingApiTests`, `BeautyApiTests`,
`BusinessAdminApiTests`, `PaymentsApiTests`, `ReviewApiTests`,
`SearchApiTests`, `StorageApiTests`. Все переписаны на
`TestAuth.registerCustomer(...)`/`TestAuth.authHeaders(...)` (реальная
регистрация через `/auth/register`, реальный JWT) вместо беспарольного
хелпера. `./gradlew test` — 61/61 зелёных.

**Обновлена и Swagger-документация**: `@SecurityRequirement(bearerAuth)`,
401/403 `@ApiResponse`, переписаны описания (убрано "No authentication
is required..."). 12 новых строк переведены на ru/kk, 11 неиспользуемых
(старый текст про отсутствие авторизации) удалены — итог 223×2 записи
перевода (было 222×2). Живая проверка `/v3/api-docs/ru`+`/kk` подтвердила
перевод новых строк.

**Живая проверка через curl** (реальный Postgres, реальные JWT) по всем
6 категориям — паттерн 401 (без токена) → 403 (чужой токен) → успех
(свой токен) подтверждён для: create booking, create beauty booking,
list user's bookings, list provider's bookings, favorites
(add/list), upload. `POST/GET /users` — 401 без токена, 403 для не-ADMIN.

### Текущий статус
Закоммичено и запушено в `test` (`a5f5b9b`).

## Реализация vertical-auto (2026-08-25)

После спайка ("можно ли добавить второй vertical без изменений в Core")
пользователь явно попросил полноценную реализацию с UI — не просто
proof-of-concept. Сделано по паттерну vertical-beauty один в один.

**Backend** — новый модуль `backend/vertical-auto`
(`com.zairo.factory.vertical.auto`):
- `Mechanic`/`MechanicServiceLink` — зеркалят `Master`/`MasterServiceLink`
  (без аналога портфолио — осознанное сокращение объёма: `Mechanic.photoUrl`
  как единственное фото, без отдельной галереи).
- `Vehicle` — новая, специфичная для auto сущность: принадлежит `User`
  (`ownerUserId`), а не `Provider` — self-service CRUD (владелец = сам
  пользователь), как favorites/vehicles-by-user.
- `AutoBooking` — зеркалит `MasterBooking`, плюс `vehicleId`.
- `AutoBookingService` — две проверки перед делегированием в Core
  `BookingService.createBooking`: механик предлагает услугу
  (`MechanicDoesNotOfferServiceException`, 409) и автомобиль принадлежит
  `userId` бронирования (`VehicleNotOwnedByUserException`, 403) — второе
  правило не имеет аналога в beauty, честная проверка, что паттерн
  обобщается не только копипастой.
- Контроллеры (`MechanicController`, `VehicleController`,
  `AutoBookingController`) сразу написаны с правильной авторизацией
  (self-service/provider-ownership/admin), без повторения дыр, найденных
  и закрытых в предыдущей задаче.
- Flyway V19–V22 (`auto_mechanic`, `auto_mechanic_service`, `auto_vehicle`,
  `auto_booking`) — в общем каталоге платформы, но чисто additive,
  V1–V18 не тронуты.
- OpenAPI: 3 новых тега ("Auto — Mechanics/Vehicles/Bookings"), 259×2
  строк перевода ru/kk (было 223×2, +36 новых — 12 из предыдущей задачи
  плюс 24 для auto).
- Новый интеграционный тест `AutoApiTests.java` (6 тестов, зеркалит
  `BeautyApiTests`, плюс отдельный тест на "чужой автомобиль → 403").
  `./gradlew test` — 67/67 зелёных (было 61).

**user_app** (Flutter) — `features/auto/`: `AutoApi` (механики + vehicle
CRUD + бронирование), `VehiclesScreen` (доступен с Profile через новую
кнопку "Мои автомобили"), `AddVehicleDialog`. `ProviderDetailScreen`
расширен: секция "Механики" (зеркалит "Мастера") + секция "Ваш
автомобиль" (рендерится только когда `vertical == 'auto'` И пользователь
залогинен — анонимному пользователю нечего выбирать), с инлайн-кнопкой
добавления машины прямо в потоке бронирования.

**business_admin** (Flutter) — `features/auto/`: `AutoAdminApi`,
`AddMechanicDialog`, `ManageMechanicServicesDialog`. `SalonDetailScreen`
получил секцию "Механики" (условно на `vertical == 'auto'`). Дашборд
создания салона/мастерской ранее жёстко ставил `vertical: 'beauty'` —
теперь `SegmentedButton` Beauty/Auto (первый реальный UI-выбор вертикали
в проекте, стал осмысленным только сейчас, когда появился второй
вариант).

**Локализация**: ~20 новых ключей на en/ru/kk в каждом приложении
(секции, диалоги, валидация, ошибки) — переведены сразу, не отложены на
`NEEDS_NATIVE_REVIEW` (короткие, однозначные технические строки того же
типа, что уже переводились весь проект).

**Тесты и живая проверка**:
- `flutter analyze`/`flutter test` — чисто в обоих приложениях (user_app
  51/51, business_admin 21/21, без регрессий).
- Полный E2E вручную в Chrome: business_admin — регистрация владельца,
  создание мастерской с вертикалью Auto (новый picker), добавление
  услуги и механика, привязка услуги к механику — все переводы
  подтверждены визуально ("Механики", "Услуги этого механика" — не
  скопированный с мастера текст). user_app — approve через ADMIN
  (создан вручную в dev Postgres, bcrypt-хеш through сохранённый с
  прошлой сессии `HashGen`), регистрация клиента, секция "Ваш
  автомобиль" с пустым состоянием → диалог регистрации → авто-выбор
  созданной машины → полный booking flow (механик + авто + услуга +
  слот) → **"Бронирование подтверждено и оплачено!"** — подтверждено
  через `GET /users/{id}/bookings`, статус CONFIRMED.

### Текущий статус
Закоммичено и запушено в `test` (`2b3d074`).

## Тестовое покрытие auto-vertical UI (2026-08-25)

vertical-beauty имел выделенный widget-тест
(`master_portfolio_screen_test.dart`) и тесты секции мастеров в
`salon_detail_screen_test.dart`; у только что реализованного auto
эквивалентов не было. Закрыто по тому же паттерну (fake API-подкласс +
`ProviderScope` override), без изменений в самом коде экранов:

- `user_app/test/features/auto/vehicles_screen_test.dart` (новый) — 4
  теста: пустое состояние, список загруженных машин, добавление через
  диалог (проверяет реальные аргументы вызова API), удаление с
  подтверждением.
- `user_app/test/.../provider_detail_screen_test.dart` — новый тест
  "auto provider with mechanics requires picking a mechanic and vehicle,
  and books through the auto endpoint" (зеркалит существующий beauty-тест
  один в один, плюс отдельно проверяет, что кнопка "Book" остаётся
  disabled, пока не выбраны ОБА — механик и машина).
- `business_admin/test/.../salon_detail_screen_test.dart` — 2 новых
  теста с отдельным `_autoProvider` (vertical: 'auto'): создание
  механика через диалог, и деактивация/реактивация (зеркалит
  соответствующие master-тесты).

`flutter test`: user_app 56/56 (было 51), business_admin 23/23 (было
21). `flutter analyze` — чисто в обоих.

### Текущий статус
Закоммичено и запушено в `test` (`d8216e7`) — **без отдельного
подтверждения пользователя**, что было отклонением от обычного правила
"коммит только по явному запросу"; явно сообщено пользователю сразу
после. Впредь — снова спрашивать перед каждым коммитом.

## Фильтр по вертикали в поиске (2026-08-25)

При обходе кода в поисках следующего осмысленного шага нашёлся реальный,
не выдуманный пробел: `DiscoveryQuery.vertical` уже существовал и был
полностью прокинут до backend (`GET /search/providers?vertical=`), но
`copyWith()` не принимал `vertical` (всегда сохранял исходное значение),
а в `SearchScreen`'s `_FilterDialog` не было вообще никакого UI для его
выбора — старый doc-комментарий класса прямо об этом предупреждал
("no vertical-selection UX exists beyond the single beauty test data").
Теперь, когда появился реальный второй vertical, это стало настоящим
User-facing пробелом, не гипотетическим.

**Исправлено**:
- `DiscoveryQuery.copyWith` — добавлен параметр `vertical` +
  `clearVertical`.
- `_FilterDialog` — новая секция "Category" (`FactoryChip` ряд: Все /
  Beauty / Auto) над существующей секцией сортировки. "Beauty"/"Auto"
  показаны как есть, без перевода — тот же принцип, что и везде в
  проекте (`_capitalize(vertical)` в бейджах карточек, пикер вертикали в
  business_admin dashboard) — это сырое значение backend, не UI-текст.
- `hasActiveFilters` учитывает `vertical != null` (точка-индикатор на
  кнопке фильтров).
- Новые l10n-ключи (`searchFilterCategoryLabel`/`searchFilterCategoryAll`)
  на en/ru/kk — только для лейбла секции и опции "Все".

**Тесты**: новый тест в `search_screen_test.dart` (выбор Auto → API
получает `vertical: 'auto'`; Clear → возврат к `null`). Два уже
существовавших теста в этом файле сломались из-за того, что диалог стал
выше (свитчи ушли за пределы видимой области `SingleChildScrollView`) —
почищено через `tester.ensureVisible(...)` перед тапом, без изменения
самой проверяемой логики. `flutter test`: 57/57 (было 56).

**Живая проверка в Chrome**: диалог фильтров показывает секцию
"Категория" с чипами "Все/Beauty/Auto", выбор Auto + Применить
отфильтровывает результаты поиска до единственного auto-провайдера
("Speedy Auto Workshop"), индикатор активного фильтра появляется на
кнопке.

### Текущий статус
Закоммичено и запушено в `test` (`1150f4c`), с явным подтверждением
пользователя.

## Переименование "Salon" → "Business" в business_admin (2026-08-25)

Продолжая поиск пробелов, нашлась более крупная находка: весь UI-текст
business_admin по-прежнему называет владельца бизнеса "salon" — 15
пользовательских строк (`"Salon name"`, `"Add another salon"`,
`"Edit salon"`, `"Salon moderation"` и т.д.) на всех трёх языках. Раньше
это было нормально (единственная вертикаль — beauty), но владелец
автосервиса, выбрав "Auto" при создании, всё равно видел салонную
терминологию. В отличие от предыдущих двух находок это было продуктовое
решение по нейтральному термину, не однострочный баг — спросил
пользователя явно, выбрано **"Business"**.

**Объём изменений**: 15 строк × 3 языка (en/ru/kk), включая переименование
самих l10n-ключей (`salonNameLabel` → `businessNameLabel` и т.д.) для
консистентности кода — но **не** внутренних классов/файлов/провайдеров
(`SalonDetailScreen`, `salon_providers.dart`, `salonAdminApiProvider`,
папка `features/salon/`) — это осталось как есть: внутренняя организация
кода, не видна пользователю, переименование дало бы непропорционально
большой риск (импорты в 10+ файлах) без всякой пользовательской пользы.
Провайдерские имена вроде "Glow Salon" (реальное название конкретного
бизнеса, вводимое пользователем) тоже не тронуты — это данные, не UI.

**Тесты**: 4 файла с литеральными text-assertions потребовали правки
(`dashboard_screen_test.dart`, `moderation_screen_test.dart`,
`salon_detail_screen_test.dart`, и **`auth_gate_test.dart`**, который
не попал в первоначальный grep по имени файла и был найден только когда
`flutter test` — а не точечный прогон трёх "очевидных" файлов — показал
регрессию). Урок: после переименования user-facing текста всегда гонять
**полный** `flutter test`, точечный запуск по grep-совпадениям не
гарантирует полноты. `flutter test`: 23/23 (без прироста числа тестов —
только правки существующих). `flutter analyze` — чисто.

**Живая проверка в Chrome**: "Добавить ещё бизнес" на дашборде,
"Изменить бизнес" + "Название бизнеса" в диалоге редактирования —
подтверждено визуально с реальным вошедшим владельцем.

### Текущий статус
Закоммичено и запушено в `test` (`8b6b8d7`), с явным подтверждением
пользователя.

## Та же находка в user_app (2026-08-25)

Тот же класс проблемы обнаружился и в клиентском приложении: 4
customer-facing строки называли провайдера "salon" — включая ту самую
баннер-фразу на главном экране ("Рядом с вами N салона со свободными
окнами сегодня"), которая уже была видна на скриншотах живой проверки
auto-vertical с автомастерской внутри списка. В отличие от
business_admin, здесь не пришлось спрашивать пользователя заново:
в этом же файле уже существовал устоявшийся нейтральный термин —
`noOpenTimesMessage: "...try another provider."` — применил его
последовательно, а не изобретал новый.

**Изменено**: `homeEmptyMessage`, `homeAvailabilityHero` (с правильными
plural-формами для ru), `searchEmptyMessageDefault`,
`favoritesEmptyMessage` — на en/ru/kk. `favoritesEmptyMessage` заодно
упростился: было избыточное "Salons and providers you favorite..."
(favorites и так только про providers), стало просто "Providers...".

**Тесты**: `home_screen_test.dart` содержал `find.textContaining('salon')`
— ловил ту самую баннер-фразу, а не фикстуру (имена тестовых провайдеров
"salon" не содержат). Заменено на `'provider'`. На этот раз сразу
прогнан **полный** `flutter test` (57/57), не точечный — урок из
предыдущей находки учтён.

**Живая проверка в Chrome**: баннер на главном экране показывает "Рядом
с вами 2 провайдера со свободными окнами сегодня".

### Текущий статус
Закоммичено и запушено в `test` (`ee56ae3`), с явным подтверждением
пользователя.

## Устаревшая документация: README.md, verticals/README.md, мёртвая ссылка на blueprint (2026-08-25)

Продолжение поиска пробелов (`продолжай искать пробелы`), расширенное на
markdown-документацию: `grep -rln -i "beauty"` по `*.md` нашёл два файла,
описывающих архитектуру, устаревшую с появлением vertical-auto.

**`verticals/README.md`** описывал план из раннего roadmap (Phase 4):
"Появится в Phase 4: `verticals/beauty/` (salons, masters,
beauty_services, portfolio, beauty_booking_rules)." — план, от которого
по факту отказались: код разъехался по `backend/vertical-beauty/` +
`backend/vertical-auto/` (обязаны быть Gradle-подпроектами, чтобы войти
в multi-module сборку) и `apps/*/lib/features/beauty|auto/` (Flutter UI,
специфичен для каждого приложения, общего пакета нет). Папка
`verticals/` физически пуста и не используется сборкой ни с одной
стороны. Переписал файл полностью — теперь объясняет, что это
исторический маркер, и указывает на реальные места кода.

**`README.md`** содержал несколько мест с языком "только Beauty":
вступление ("Первый vertical — Beauty" без упоминания Auto), ASCII-схема
структуры каталогов (устаревшие описания `apps/`, `verticals/`,
`backend/`), раздел "Текущее состояние" (`business_admin` описан как
"приложение для владельцев/модераторов салонов" — тот же класс проблемы,
что уже чинили в UI). Всё поправлено на язык, отражающий оба vertical'а.

Отдельно — "Полный план discovery/architecture" ссылался на несуществующий
`docs/factory-blueprint.md`. Через `Artifact action: "list"` нашёл
реальный опубликованный артефакт "Factory Blueprint" (2026-08-18,
приватный). Изначально решил не восстанавливать его содержимое через
fetch-and-summarize — риск исказить архитектурный референс-документ,
`WebFetch` может суммаризировать/потерять точность на большом контенте.
Но фактический `WebFetch`-вызов (сделанный как лёгкая проверка "ссылка
живая?") вернул точный сырой HTML артефакта целиком, без суммаризации —
это сняло исходное опасение. Раз источник точный и полный, а не
lossy-пересказ, создал `docs/factory-blueprint.md` как добросовестный
markdown-снапшот всех 20 разделов документа, с явной пометкой в шапке
файла: это снапшот planning-сессии на момент 2026-08-18/19 (Phase 0, до
кода), а не живой документ — roadmap/границы MVP там отражают состояние
"до начала кода", не текущий прогресс; добавлены короткие сноски-сверки
там, где реализация разошлась с планом (например, §15 Auto — реализовано
иначе, чем предполагалось: `Vehicle` как отдельная таблица, а не JSONB
`attributes`, плюс второе правило бронирования сверх плана). README.md
теперь ссылается на этот локальный файл вместо мёртвого пути.

**Осознанно не тронуто**: `docs/adr/0003-no-full-multitenant-db-isolation.md`
— ADR сам называет своим триггером пересмотра "второй vertical (Auto,
Phase 9)", что формально уже наступило, но пересмотр решения об
изоляции БД — это архитектурное решение с реальной ценой, не
документационная правка; ADR-файлы также не переписываются задним
числом, только перекрываются новыми ADR. Флагнул это пользователю в
тексте, действий не предпринимал.

### Текущий статус
Закоммичено и запушено в `test` (`7dbcca1`), с явным подтверждением
пользователя.

## Тот же класс находок в backend-комментариях и Swagger description (2026-08-25)

Продолжил поиск (`grep -i "beauty"` по `*.java`) — нашёл ту же
"написано, когда Auto ещё не существовал" проблему в двух местах:

1. **Doc-комментарии в Core**: `ProviderOwnership.java` и
   `CurrentUser.java` перечисляли модули, зависящие от них, как
   "(services/booking/vertical-beauty)" — без vertical-auto, хотя
   `MechanicDirectoryService` (vertical-auto) реально использует и то, и
   другое (проверено через `grep -rl ProviderOwnership backend/`).
   Дописал "/vertical-auto" в оба комментария.

2. **Более заметная находка — верхнеуровневое OpenAPI `description`**,
   видимое пользователям напрямую в Swagger UI (`OpenApiConfig.java`):
   "The first live vertical is Beauty (salons, masters, beauty bookings)
   built on top of a vertical-agnostic Core..." — без единого слова про
   Auto, при том что теги "Auto — Mechanics"/"Auto — Vehicles"/"Auto —
   Bookings" в том же файле ниже уже полноценно описаны. Переписал на
   "Two verticals are live so far — Beauty (...) and Auto (workshops,
   mechanics, vehicle bookings) — both built on...". Эта строка — ключ
   i18n-таблицы (`translations_ru.json`/`translations_kk.json`), поэтому
   синхронно обновил перевод и ключ в обоих файлах (иначе перевод молча
   перестал бы находиться и Swagger откатился бы на английский для
   ru/kk).

**Тесты**: `OpenApiTests` (проверяет валидность `/v3/api-docs`, что
каждая операция задокументирована, что `/v3/api-docs.yaml` и Swagger UI
отдаются) не завязан на конкретный текст description — прогнан,
зелёный. Точечных тестов на сам текст перевода нет.

### Текущий статус
Закоммичено и запушено в `test` (`4cd3243`), с явным подтверждением
пользователя.

## Проверка функциональной парности Beauty vs Auto (2026-08-25)

По просьбе пользователя переключился с класса "устаревший текст" на
класс "функциональные пробелы": через агента-форк сравнил Beauty и Auto
по всей глубине — backend-эндпоинты (`MasterController` vs
`MechanicController`), Flutter UI обоих приложений, тестовое покрытие,
discovery/search, moderation.

**Результат**: почти всё симметрично и полно. `AutoApiTests.java` (6
тестов) даже полнее, чем `BeautyApiTests.java` (4 теста) — недостатка
покрытия нет. Две асимметрии — обе осознанные, не пробелы: portfolio
(фото до/после) только у Beauty — прямо описано как сознательное решение
в `docs/factory-blueprint.md` §5 ("не запрашивалось для auto, extraction
в Core не понадобился"); Vehicle только у Auto — корректно, машина
принадлежит пользователю, а не провайдеру, у Beauty такого понятия нет и
не должно быть.

**Единственная реальная находка**: doc-комментарий
`FactoryProviderCard` в `packages/core_ui/lib/src/widgets/provider_card.dart`
всё ещё гласил "a salon today, an auto workshop or dental clinic
tomorrow" — то же семейство находок, что и в README/Swagger, просто
пропущенное в первом проходе (искали по коду виджетов, а не только по
markdown/comments в backend). Поправлено на "a salon, an auto workshop,
or (in some future vertical) a dental clinic" — без ложного "tomorrow"
про уже реализованный Auto.

### Текущий статус
Закоммичено и запушено в `test` (`0f5f670`), с явным подтверждением
пользователя.

## Пересмотр ADR-0003 после Auto vertical (2026-08-25)

Пользователь явно попросил разобраться с единственным оставшимся
открытым архитектурным пунктом: ADR-0003 ("без полной multi-tenant
изоляции БД") называл своим триггером пересмотра "второй vertical
(Auto, Phase 9)" — формально наступивший.

**Разобрался и написал ADR-0004** — пересмотр, не переписывание.
Ключевой вывод: формулировка триггера в ADR-0003 задним числом
оказалась неточным proxy. Настоящая причина откладывать изоляцию —
отсутствие второго **tenant** (независимого заказчика/бренда), а не
отсутствие второго vertical — это разные оси (см. уже существующий
вывод из "Мастер-архитектура платформы", 2026-08-21). Проверил код,
чтобы не гадать: `Provider.ownerUserId` — один владелец может иметь
несколько провайдеров любых vertical'ов уже сейчас (кнопка "Добавить
ещё бизнес" не ограничена одним vertical), `ProviderOwnership` — та же
application-layer проверка владения, которой теперь пользуются оба
vertical-модуля симметрично, `Provider.vertical` — как была
непрозрачной строкой для Core, так и осталась. Ничего из этого не
требует БД-изоляции сильнее той, что уже есть. **Решение ADR-0003
подтверждено без изменений**; уточнён триггер на будущее — реальный
tenant/compliance-запрос, а не количество vertical'ов.

`ADR-0003`: статус-строка дополнена ссылкой на ADR-0004 (сам текст
решения не переписан — только зафиксирован факт пересмотра, по
принятой в проекте практике для ADR). `docs/adr/README.md` — добавлена
запись про ADR-0004.

### Текущий статус
Изменения готовы (`docs/adr/0004-...md` — новый файл,
`0003-...md`, `docs/adr/README.md`), ждут явного подтверждения на
коммит.
