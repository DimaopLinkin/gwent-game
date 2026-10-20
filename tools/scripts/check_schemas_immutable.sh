#!/usr/bin/env bash
# Проверка для pull request: файлы схем базы (drift_schemas/), уже попавшие в базовую ветку, не меняются и не
# удаляются, допустимы только новые файлы (ADR 0024). Использование: tools/scripts/check_schemas_immutable.sh [база]
# База по умолчанию origin/dev; в CI нужна история (fetch-depth: 0). Скрипт совместим с bash 3.2.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

base="${1:-origin/dev}"
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "check_schemas_immutable.sh: нет базовой ветки '$base' (нужна история: fetch-depth: 0)" >&2
  exit 1
fi

# Три точки: сравнение с общим предком, поэтому новые коммиты базовой ветки не мешают.
changed="$(git diff --name-status --no-renames "$base...HEAD" -- drift_schemas/ | grep -v '^A' || true)"
if [ -n "$changed" ]; then
  echo "Файлы схем базы, уже попавшие в $base, изменены или удалены (разрешено только добавлять новые):" >&2
  echo "$changed" >&2
  echo "Ошибку в схеме исправляют следующей версией (docs/adr/0024-database-migrations.md)." >&2
  exit 1
fi
echo "Схемы базы: существующие файлы не менялись."
