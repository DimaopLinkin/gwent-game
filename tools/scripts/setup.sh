#!/usr/bin/env bash
# Подготовка проекта: зависимости и кодогенерация.
#
# Все команды подготовки (pub get, build_runner, gen-l10n и т. п.) добавляются сюда, а не в CI или README.
# Использование:
#   tools/scripts/setup.sh                        # всё: пакеты из packages/ и приложение
#   tools/scripts/setup.sh packages/gwent_engine  # только перечисленные папки (CI для пакетов)
#
# Для Flutter-проектов нужен flutter, для чистых Dart-пакетов достаточно dart.
# Скрипт совместим с bash 3.2 (стоит на macOS по умолчанию).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

# Версия Flutter проекта (как на Mac и в CI). Другая версия меняет pubspec.lock: такие правки не коммитить.
expected_flutter=3.41.0
if command -v flutter >/dev/null 2>&1; then
  actual_flutter="$(flutter --version 2>/dev/null | sed -n 's/^Flutter \([0-9.]*\).*/\1/p')"
  if [ -n "$actual_flutter" ] && [ "$actual_flutter" != "$expected_flutter" ]; then
    echo "setup.sh: внимание, Flutter $actual_flutter, а проекту нужен $expected_flutter" >&2
  fi
fi

if [ "$#" -gt 0 ]; then
  targets=("$@")
else
  targets=()
  for dir in packages/*/; do
    [ -f "${dir}pubspec.yaml" ] && targets+=("${dir%/}")
  done
  targets+=(".")
fi

for target in "${targets[@]}"; do
  if [ ! -f "$target/pubspec.yaml" ]; then
    echo "setup.sh: в '$target' нет pubspec.yaml" >&2
    exit 1
  fi

  if grep -qE '^[[:space:]]+sdk:[[:space:]]+flutter' "$target/pubspec.yaml"; then
    tool=flutter
  else
    tool=dart
  fi

  echo "==> $target ($tool)"
  (
    cd "$target"
    "$tool" pub get

    if grep -qE '^[[:space:]]+build_runner:' pubspec.yaml; then
      dart run build_runner build --delete-conflicting-outputs
      # Генераторы пишут код под 80 колонок; приводим его к ширине проекта, иначе упадёт проверка формата.
      find . -path ./build -prune -o -path ./.dart_tool -prune -o -type f \
        \( -name '*.g.dart' -o -name '*.freezed.dart' -o -name '*.drift.dart' -o -name '*.mocks.dart' \) -print0 |
        xargs -0 -r dart format >/dev/null
    fi

    if [ "$tool" = flutter ] && [ -f l10n.yaml ]; then
      flutter gen-l10n
    fi
  )
done
