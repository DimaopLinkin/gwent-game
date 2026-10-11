# Гвинт

Мини-игра Гвинт из «Ведьмака 3» на Flutter. Android (APK) и iOS (Ad Hoc), без публикации в сторах.

## Структура

- `lib/`, `test/` — Flutter-приложение.
- `packages/gwent_engine` — движок правил, чистый Dart.
- `packages/gwent_content` — пакет контента (модели, парсер, валидатор), чистый Dart.
- `docs/hand` — данные карт и правила, источник правды.
- `docs/adr`, `docs/spec` — архитектурные решения и требования к фичам.

Правила для разработчиков и агентов, команды проверки и git-процесс описаны в [CLAUDE.md](CLAUDE.md).

## Быстрая проверка

```sh
tools/scripts/setup.sh
(cd packages/gwent_engine && dart test)
(cd packages/gwent_content && dart test)
flutter analyze && flutter test
```
