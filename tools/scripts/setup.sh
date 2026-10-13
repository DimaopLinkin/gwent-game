#!/usr/bin/env bash
# Подготовка проекта: зависимости и кодогенерация.
#
# Все команды подготовки (pub get, build_runner, gen-l10n и т. п.) добавляются сюда, а не в CI или README.
# Использование:
#   tools/scripts/setup.sh                        # всё: пакеты из packages/, утилиты из tools/ и приложение
#   tools/scripts/setup.sh packages/gwent_engine  # только перечисленные папки (CI для пакетов)
#
# Для приложения (папка «.») скрипт сначала собирает пакет контента из docs/hand в assets/content/:
# это генерируемый файл, он не коммитится. Иконки приложения (Android и iOS) скрипт воспроизводит из tools/app_icon/ и
# кладёт в ios/ и android/: эти файлы коммитятся.
#
# Для Flutter-проектов нужен flutter, для чистых Dart-пакетов достаточно dart.
# Скрипт совместим с bash 3.2 (стоит на macOS по умолчанию).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

# Версия Flutter проекта (как на Mac и в CI). Другая версия меняет pubspec.lock: такие правки не коммитить.
expected_flutter=3.41.0
if command -v flutter >/dev/null 2>&1; then
  # `|| true`: сломанный flutter не должен молча останавливать скрипт, это только предупреждение.
  actual_flutter="$(flutter --version 2>/dev/null | sed -n 's/^Flutter \([0-9.]*\).*/\1/p' || true)"
  if [ -n "$actual_flutter" ] && [ "$actual_flutter" != "$expected_flutter" ]; then
    echo "setup.sh: внимание, Flutter $actual_flutter, а проекту нужен $expected_flutter" >&2
  fi
fi

if [ "$#" -gt 0 ]; then
  targets=("$@")
else
  targets=()
  for dir in packages/*/ tools/*/; do
    [ -f "${dir}pubspec.yaml" ] && targets+=("${dir%/}")
  done
  targets+=(".")
fi

# Пакет контента для ассетов приложения: docs/hand/data → assets/content/gwent-w3-base (manifest, pack, strings).
# Сборка проверяет пакет тем же загрузчиком, что и приложение, и падает, если данные не прошли проверку.
build_content_pack() {
  echo "==> пакет контента (tools/build_pack)"
  (
    cd tools/build_pack
    dart pub get
    dart run bin/build_pack.dart \
      --data "$root/docs/hand/data" \
      --identity "$root/docs/hand/content_pack.json" \
      --out "$root/assets/content/gwent-w3-base"
  )
}

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

  if [ "$target" = "." ]; then
    build_content_pack
  fi

  echo "==> $target ($tool)"
  (
    cd "$target"
    "$tool" pub get

    # Миграции Drift (базы перечислены в build.yaml, схемы всех версий коммитятся в drift_schemas/<база>/):
    # make-migrations сохраняет схему новой версии, падает, если схема изменилась без увеличения schemaVersion,
    # и собирает шаги миграций (<база>.steps.dart). schema generate собирает тестовые схемы всех версий.
    if [ -f build.yaml ] && grep -qE '^[[:space:]]+databases:' build.yaml; then
      dart run drift_dev make-migrations --no-test
      # В CI новая схема, созданная здесь, значит, что её забыли закоммитить: без файла схемы версия потеряна
      # для будущих проверок миграций.
      if [ -n "${CI:-}" ] && [ -n "$(git status --porcelain -- drift_schemas/)" ]; then
        echo "setup.sh: схема базы новой версии не закоммичена:" >&2
        git status --porcelain -- drift_schemas/ >&2
        exit 1
      fi
      for schemas in drift_schemas/*/; do
        [ -d "$schemas" ] || continue
        dart run drift_dev schema generate --data-classes --companions "$schemas" "test/drift/$(basename "$schemas")/generated/"
      done
    fi

    if grep -qE '^[[:space:]]+build_runner:' pubspec.yaml; then
      dart run build_runner build --delete-conflicting-outputs
    fi

    # Генераторы пишут код под 80 колонок; приводим его к ширине проекта, иначе упадёт проверка формата.
    find . -path ./build -prune -o -path ./.dart_tool -prune -o -type f \
      \( -name '*.g.dart' -o -name '*.freezed.dart' -o -name '*.drift.dart' -o -name '*.mocks.dart' \
      -o -name '*.steps.dart' -o -path './test/drift/*/generated/*.dart' \) -print0 |
      xargs -0 -r dart format >/dev/null

    # Иконки из PNG-слоёв tools/app_icon/. Результат коммитится: сборка читает готовые файлы, а скрипт лишь
    # воспроизводит их. Android (mipmap, адаптивная иконка, монохромный слой) делает flutter_launcher_icons по
    # flutter_launcher_icons.yaml; iOS это один мастер 1024×1024 в каталоге ресурсов (Xcode 14+ сам нарезает размеры).
    if [ -f flutter_launcher_icons.yaml ]; then
      dart run flutter_launcher_icons
      cp tools/app_icon/app_icon_ios.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
    fi

    # Локализация: вывод в output-dir из l10n.yaml (не коммитится), формат по analysis_options.yaml (format: true).
    if [ "$tool" = flutter ] && [ -f l10n.yaml ]; then
      flutter gen-l10n
    fi
  )
done
