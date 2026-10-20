#!/usr/bin/env bash
# Тесты SQL-миграций Supabase (supabase/migrations) на обычном PostgreSQL, без облака и Docker.
#
# Нужен psql и доступ к серверу PostgreSQL 15 или новее под суперпользователем; подключение берётся из
# стандартных переменных PGHOST, PGPORT, PGUSER, PGPASSWORD. Скрипт создаёт отдельную базу gwent_supabase_test,
# пересоздаёт её, применяет supabase/tests/bootstrap.sql (имитация ролей, auth и realtime), все миграции по порядку
# имён и supabase/tests/*_test.sql. Первая ошибка останавливает прогон с ненулевым кодом.
# Роли anon, authenticated и service_role создаются на сервере, если их ещё нет (они общие для всех баз сервера).
#
# Использование: tools/scripts/test_supabase.sh
# Совместим с bash 3.2 (macOS).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
db=gwent_supabase_test

if ! command -v psql >/dev/null 2>&1; then
  echo "test_supabase.sh: не найден psql" >&2
  exit 1
fi

run() {
  psql --no-psqlrc --quiet --set ON_ERROR_STOP=1 --dbname "$1" --file "$2"
}

psql --no-psqlrc --quiet --set ON_ERROR_STOP=1 --dbname postgres \
  --command "drop database if exists $db with (force)" \
  --command "create database $db"

echo "==> bootstrap"
run "$db" "$root/supabase/tests/bootstrap.sql"

for file in "$root"/supabase/migrations/*.sql; do
  echo "==> миграция $(basename "$file")"
  run "$db" "$file"
done

for file in "$root"/supabase/tests/*_test.sql; do
  echo "==> тесты $(basename "$file")"
  run "$db" "$file"
done

psql --no-psqlrc --quiet --set ON_ERROR_STOP=1 --dbname postgres --command "drop database $db with (force)"
echo "supabase: все тесты прошли"
