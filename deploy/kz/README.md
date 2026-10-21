# Боевой запуск на одном VPS в Казахстане

Всё, что хранит данные, работает на **одном** сервере в РК: PostgreSQL, фото
(MinIO), резервные копии, логи. Наружу открыты только порты 80/443 (Caddy,
HTTPS выпускается сам). Не используются Neon, Cloudflare R2, Render и другие
зарубежные хранилища.

```
интернет ──443──▶ Caddy ──▶ backend (Spring Boot) ──▶ PostgreSQL
                                   └────────────────▶ MinIO (фото)
                      backup (раз в сутки) ──▶ ./backups
```

> Файлы подготовлены и проверены только на синтаксис (`docker compose config`).
> **На реальном сервере они ещё не запускались.** Первый запуск — на тестовом
> домене и без настоящих клиентов.

## 1. Что арендовать

- VPS **минимум 2 vCPU / 4 GB RAM / 60 GB SSD** (backend ~1,5 GB, Postgres,
  MinIO, сборка образа). Ubuntu 24.04 LTS.
- Провайдер с **дата-центром физически в Казахстане** (например PS.kz, Hoster.kz,
  QazCloud — цены и условия смотрите у них, я их не проверял). Спросите
  письменно: «дата-центр в РК, реквизиты договора, возможен ли второй сервер
  в другом ДЦ для копий».
- Домен (лучше `.kz`) и A-запись `api.<домен>` на IP сервера.
- **Второй сервер или хранилище в РК** для копий (см. §6). Копия на том же диске
  — это не копия.

## 2. Подготовка сервера (один раз)

```bash
adduser deploy && usermod -aG sudo deploy        # вход только по SSH-ключу
# /etc/ssh/sshd_config: PasswordAuthentication no, PermitRootLogin no
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw enable
apt install -y fail2ban unattended-upgrades git
curl -fsSL https://get.docker.com | sh && usermod -aG docker deploy
```

## 3. Запуск

```bash
git clone https://github.com/ADatkashov/zairo.git && cd zairo/deploy/kz
cp .env.example .env && chmod 600 .env
# заполните .env; секреты: openssl rand -base64 48
docker compose up -d --build        # первая сборка 5–10 минут
curl https://api.<домен>/actuator/health      # {"status":"UP"}
docker compose logs -f backend      # если не стартует — причина здесь
```

Backend в режиме `prod` **намеренно не запустится**, пока не заданы реальные
секреты и SMS (Twilio или `OTP_MOCK_CODE`). Список недостающего он выводит в лог.
Вход через Google и Apple в этой схеме **выключен** (`GOOGLE_OAUTH_ENABLED=false`,
`APPLE_OAUTH_ENABLED=false`): ключи для них не нужны, сервер отклоняет такие входы.

Миграции базы (Flyway) применяются при старте сами.

**Первый администратор платформы** через API создать нельзя. Создаётся одной
командой (подставьте свои e-mail и пароль):

```bash
docker compose exec postgres psql -U zairo -d zairo -c "
create extension if not exists pgcrypto;
insert into platform_admin_account(id,email,password_hash,display_name,role,active,created_at,updated_at)
values (gen_random_uuid(),'admin@your.kz',crypt('СИЛЬНЫЙ_ПАРОЛЬ',gen_salt('bf',10)),'Admin','PLATFORM_ADMIN',true,now(),now());"
```

## 4. Приложения

Соберите с боевым адресом `https://api.<домен>/api/v1` (параметр `api_base_url`,
см. `docs/ci-cd.md` §10) и с выключенным входом через Google и Apple:
`--dart-define=GOOGLE_SIGN_IN_ENABLED=false --dart-define=APPLE_SIGN_IN_ENABLED=false`
(кнопок в приложении не будет; код остаётся). Опубликуйте в Google Play / App Store. Сами приложения
данных пользователей на серверах не хранят.

## 5. Обновление

```bash
cd zairo && git pull && cd deploy/kz && docker compose up -d --build
```
Простой — несколько секунд на перезапуск backend. Перед крупным обновлением
сделайте внеочередную копию: `docker compose restart backup` (делает копию при старте).

## 6. Резервные копии и восстановление

Контейнер `backup` каждую ночь (в 03:00 по времени сервера) кладёт в `./backups`
дамп базы (`db-*.dump`) и архив фото (`media-*.tar.gz`), хранит 14 дней.

**Обязательно настройте копирование на второй сервер в РК**, например с него по cron:
```bash
rsync -a --delete-after deploy@основной:/home/deploy/zairo/deploy/kz/backups/ /srv/zairo-backups/
```

Восстановление базы (на пустой Postgres):
```bash
docker compose stop backend
docker compose exec -T postgres pg_restore -U zairo -d zairo --clean --if-exists < backups/db-XXXX.dump
docker compose start backend
```
Фото: распаковать `media-*.tar.gz` в том `minio_data` при остановленном `minio`.

**Раз в месяц проверяйте восстановление на тестовом сервере** — копия, которую
ни разу не восстанавливали, может оказаться нерабочей.

## 7. Данные и закон РК — что проверить

Я не юрист; по моим сведениям закон «О персональных данных и их защите»
требует хранить базы с персональными данными граждан РК на серверах в РК.
Проверьте с юристом и требования к уведомлениям/защите информации.

Что в **этой схеме** остаётся в РК: база, фото, копии, логи, сертификаты.

Что в **коде** сегодня уходит за рубеж или требует решения:

| Что | Почему | Что делать |
|---|---|---|
| SMS-коды через **Twilio** | Номера телефонов уходят в США; режим `prod` требует Twilio (или тестовый `OTP_MOCK_CODE`) | Подключить казахстанского SMS-провайдера: нужен новый отправитель в `backend/auth` и правка проверки `ProductionSecretsValidator`. Это доработка кода, в compose не решается |
| Вход через **Google / Apple** | Токен проверяется на их серверах | **Выключено** (`*_OAUTH_ENABLED=false`, сборка с `*_SIGN_IN_ENABLED=false`); код сохранён, включается обратно переменными. Facebook в приложении уже не предлагается |
| Push-уведомления | В приложениях Firebase нет — сейчас не используется | Если добавите FCM/APNs, учесть то же самое |
| Платежи | Freedom Pay — казахстанский | Внешних проблем нет |
| Карты | Приложение лишь открывает ссылки на 2GIS/Google Maps | Данные пользователя не передаются |

Рекомендую начать с пункта про SMS: пока он не решён, «все данные в РК» в
полной мере не выполняется, даже если сервер стоит в Алматы.

## 8. Чего здесь нет (осознанно)

- Мониторинга и алертов (метрики Prometheus есть в backend, `docs/ci-cd.md` §13).
- Высокой доступности: один сервер — при его падении сервис недоступен до
  восстановления. Для первых клиентов обычно приемлемо.
- Веб-версий админок (`business_admin`, `platform_admin`) — это Flutter-приложения;
  если нужны как сайты, добавляется ещё один статический сайт в Caddy.
