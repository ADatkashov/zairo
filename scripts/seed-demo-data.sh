#!/usr/bin/env bash
# Заполняет backend демо-данными через публичный API: четыре бизнеса (2 beauty,
# auto, cleaning) с услугами из каталога, мастерами, недельным графиком, плюс
# один клиент. Нужен, чтобы приложения (и скриншоты) было на чём показывать.
#
# Использование:
#   ./scripts/seed-demo-data.sh                       # локальный backend :8080
#   BASE_URL=https://host/api/v1 ADMIN_EMAIL=... ADMIN_PASSWORD=... ./scripts/seed-demo-data.sh
#
# Новые бизнесы всегда PENDING; скрипт одобряет их через платформенный API,
# поэтому нужен PLATFORM_ADMIN. Первую учётку админа нельзя создать через API —
# локально её можно завести одной командой, если задан PG_CONTAINER (имя
# docker-контейнера с Postgres): будет создан admin@zairo-demo.test.
#
# Требуются: curl, jq, python3 (и docker, если указан PG_CONTAINER).
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080/api/v1}"
PASSWORD="${DEMO_PASSWORD:-Demo12345!}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@zairo-demo.test}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-DemoAdmin123!}"

api() { curl -sS --max-time 60 "$@"; }
json() { api -H 'Content-Type: application/json' "$@"; }

if [ -n "${PG_CONTAINER:-}" ]; then
  docker exec -i "$PG_CONTAINER" psql -U app_factory -d app_factory -q <<SQL
create extension if not exists pgcrypto;
insert into platform_admin_account(id,email,password_hash,display_name,role,active,created_at,updated_at)
values (gen_random_uuid(),'$ADMIN_EMAIL',crypt('$ADMIN_PASSWORD',gen_salt('bf',10)),'Demo Admin','PLATFORM_ADMIN',true,now(),now())
on conflict do nothing;
SQL
fi

ADMIN_TOKEN=$(json -X POST "$BASE_URL/platform/auth/login" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | jq -r '.accessToken // empty')
[ -n "$ADMIN_TOKEN" ] || echo "! Нет PLATFORM_ADMIN ($ADMIN_EMAIL): бизнесы останутся PENDING и не попадут в поиск."

# Недельный график: каждый день 10-14 и 15-19, слоты по часу.
HOURS=$(python3 -c "import json;print(json.dumps([{'dayOfWeek':d,'startTime':a,'endTime':b} for d in range(1,8) for a,b in (('10:00:00','14:00:00'),('15:00:00','19:00:00'))]))")

# create_business VERTICAL NAME OWNER EMAIL LAT LON STAFF1 STAFF2
create_business() {
  local vertical="$1" name="$2" owner="$3" email="$4" lat="$5" lon="$6" staff1="$7" staff2="$8"
  echo "=== $name ($vertical)"

  local reg token owner_id
  reg=$(json -X POST "$BASE_URL/auth/register" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\",\"displayName\":\"$owner\",\"role\":\"PROVIDER_OWNER\"}")
  token=$(echo "$reg" | jq -r '.accessToken // empty')
  if [ -z "$token" ]; then  # уже есть — просто входим
    reg=$(json -X POST "$BASE_URL/auth/login" -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\"}")
    token=$(echo "$reg" | jq -r '.accessToken')
  fi
  owner_id=$(echo "$reg" | jq -r '.user.id')
  local auth=(-H "Authorization: Bearer $token")

  local provider provider_id
  provider=$(json -X POST "$BASE_URL/providers" "${auth[@]}" \
    -d "{\"ownerUserId\":\"$owner_id\",\"name\":\"$name\",\"vertical\":\"$vertical\",\"latitude\":$lat,\"longitude\":$lon}")
  provider_id=$(echo "$provider" | jq -r '.id')
  [ "$provider_id" != null ] || { echo "Не создан бизнес: $provider"; exit 1; }

  # Бизнес может предлагать только услуги из каталога своего типа.
  local business_type_id svc_ids=() i=0 cs title
  business_type_id=$(api "$BASE_URL/providers/$provider_id" | jq -r '.businessTypeId')
  while IFS='|' read -r cs title; do
    i=$((i + 1))
    svc_ids+=("$(json -X POST "$BASE_URL/providers/$provider_id/services" "${auth[@]}" \
      -d "{\"title\":\"$title\",\"catalogServiceId\":\"$cs\",\"durationMinutes\":$((30 + i * 20)),\"price\":$((3000 + i * 2500)),\"currency\":\"KZT\"}" | jq -r '.id')")
  done < <(api "$BASE_URL/business-types/$business_type_id/services" | jq -r '.[0:3][] | "\(.id)|\(.nameRu)"')

  local staff_path link_prefix
  case "$vertical" in
    beauty)   staff_path="beauty/providers/$provider_id/masters";      link_prefix="beauty/masters" ;;
    auto)     staff_path="auto/providers/$provider_id/mechanics";      link_prefix="auto/mechanics" ;;
    cleaning) staff_path="cleaning/providers/$provider_id/cleaners";   link_prefix="cleaning/cleaners" ;;
    *)        staff_path="providers/$provider_id/staff";               link_prefix="staff" ;;
  esac

  local staff_name staff_id svc
  for staff_name in "$staff1" "$staff2"; do
    staff_id=$(json -X POST "$BASE_URL/$staff_path" "${auth[@]}" \
      -d "{\"displayName\":\"$staff_name\",\"bio\":null,\"photoUrl\":null}" | jq -r '.id')
    for svc in "${svc_ids[@]}"; do
      api -o /dev/null -X POST "$BASE_URL/$link_prefix/$staff_id/services/$svc" "${auth[@]}"
    done
    # PUT-график сам создаёт слоты на ближайшие дни.
    json -o /dev/null -X PUT "$BASE_URL/providers/$provider_id/workers/$staff_id/schedule" "${auth[@]}" \
      -d "{\"zoneId\":\"Asia/Almaty\",\"slotMinutes\":60,\"breakMinutes\":0,\"hours\":$HOURS}"
  done

  if [ -n "$ADMIN_TOKEN" ]; then
    json -o /dev/null -X PATCH "$BASE_URL/platform/businesses/$provider_id/status" \
      -H "Authorization: Bearer $ADMIN_TOKEN" -d '{"status":"ACTIVE","reason":"demo seed"}'
  fi
  echo "    provider $provider_id, владелец $email / $PASSWORD"
}

create_business beauty   "Almaty Beauty Studio" "Aigerim Salon"  salon.almaty1@zairo-demo.test    43.238293 76.945465 "Айгуль Стилист" "Динара Стилист"
create_business beauty   "Glam Studio Almaty"   "Madina Glam"    salon.almaty2@zairo-demo.test    43.242    76.912    "Асель Мастер"   "Гульнара Мастер"
create_business auto     "AutoFix Almaty"       "Yerlan Auto"    auto.workshop1@zairo-demo.test   43.222    76.851    "Ерлан Механик"  "Даулет Механик"
create_business cleaning "ChistoDom"            "Aigul Cleaning" cleaning.company1@zairo-demo.test 43.249   76.905    "Айгуль Клинер"  "Мадина Клинер"

json -o /dev/null -X POST "$BASE_URL/auth/register" \
  -d "{\"email\":\"client@zairo-demo.test\",\"password\":\"$PASSWORD\",\"displayName\":\"Алия Клиент\",\"role\":\"CUSTOMER\"}" || true
echo "Клиент: client@zairo-demo.test / $PASSWORD"
echo "SEEDED"
