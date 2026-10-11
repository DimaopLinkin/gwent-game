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
    fi

    if [ "$tool" = flutter ] && [ -f l10n.yaml ]; then
      flutter gen-l10n
    fi
  )
done
