# Гвинт (мини-игра из «Ведьмака 3») на Flutter

Копия именно мини-игры из The Witcher 3, а не отдельной игры CDPR. Пользователю отвечать по-русски.

## О проекте

- Репозиторий: https://github.com/DimaopLinkin/gwent-game (закрытый), ветки `main` и `dev`.
- Платформы: Android и iOS, портретная ориентация. В сторах не публикуется: Android APK, iOS Ad Hoc под корпоративным аккаунтом Apple Developer (согласовано с работодателем).
- Режимы: игра на одном телефоне, затем сетевая игра двух телефонов (Wi-Fi, потом Bluetooth LE, потом сервер), позже ИИ-соперник.
- Версии: ровно Flutter 3.41.0, Dart 3.11.0 (как на Mac пользователя и в CI). В облаке ставить эту же версию. Другая версия Flutter меняет в `pubspec.lock` пакеты, закреплённые SDK (`matcher`, `test_api` и т. п.); такие правки не коммитить. `setup.sh` предупреждает о несовпадении версии.
- Планы и проекты вне репозитория (папка проекта Claude): `/mnt/project-files/gwent/` (`dev-process.md`, `network_communication_specification.md`, `content_import_design.md`, `fix_log.md`). Принятые там решения переносятся в `docs/adr` и `docs/spec`.

## Источники правды

- Данные карт: `docs/hand/data/*.json`, колоды фракций: `docs/hand/cards/**/*_cards_deck.json`. Описания схем `*_schema.md` вторичны: при расхождении прав JSON (позже их заменит JSON Schema). Правила игры: `docs/hand` (`main.md` и документ правил, когда появится). Другие источники правил не использовать: сгенерированный черновик `docs/ai_1` удалён намеренно.
- Изменение данных карт записывается в `docs/hand/CHANGELOG-data.md`: что, почему, источник. При каждой правке данных увеличивается `pack_version` в `docs/hand/content_pack.json`.
- Числовые параметры партии и колоды: `docs/hand/data/game_rules/game_rules_data.json` (значения из `main.md`).
- Пакет контента (формат, сборка, проверка): `docs/adr/0002-content-pack.md`. Новый тег способности в `docs/hand` сопоставляется с эффектом в `tools/build_pack/lib/src/effect_mapping.dart`, иначе сборка упадёт.
- Пакет контента → движок: `lib/src/features/content/domain/engine_content.dart` (`mapContentToEngine`, `engineCapabilities`). Новый эффект пакета или способность движка сопоставляются там; числа перков фракций зашиты в движок, и пакет с другими числами приложение отклоняет. Контент для партии и конструктора колод даёт сценарий `LoadGameContent` из `AppDependencies`.
- UUID карты не меняется никогда. Колоды и сетевой протокол ссылаются только на UUID.
- Архитектурные решения: `docs/adr/NNNN-название.md`. Требования к фичам: `docs/spec/<фича>.md`.
- Решили что-то новое — записать в репозиторий (ADR, spec или этот файл), а не оставлять в переписке.

## Архитектура

Код строится по чистой слоистой архитектуре на абстракциях. Это обязательное правило для всех задач.

Слои и направление зависимостей (зависимости смотрят только внутрь, к домену):

| Слой | Что там | Может зависеть от |
|---|---|---|
| domain | сущности, правила, интерфейсы репозиториев и сервисов; движок `gwent_engine`, ИИ-соперник `gwent_ai`, модели `gwent_content` и протокол `gwent_net` | Dart SDK, другие доменные пакеты и чистые Dart-библиотеки без Flutter и `dart:io` (`crypto`, `collection`, `meta`, аннотации генераторов) |
| application | сценарии (use cases): начать матч, сыграть карту, сохранить колоду | domain |
| data | реализации интерфейсов: источники контента, Drift, сетевые транспорты, файловый кэш | domain |
| presentation | виджеты и держатели состояния экранов | application, domain |

- Новая внешняя зависимость domain-пакета объясняется в описании PR.
- Domain не знает о Flutter, БД, сети и файлах. Presentation не обращается к Drift, сети или `rootBundle` напрямую, только через сценарии и интерфейсы.
- Всё внешнее (хранилище, источник контента, транспорт, время, случайность) скрыто за интерфейсом (`abstract interface class`). Реализации живут в data и подставляются в одной точке сборки (composition root в `lib/src/app/`, её вызывает `lib/main.dart`). В тестах подставляются фейки, а не моки сетей и БД.
- Раскладка приложения: `lib/src/features/<фича>/{domain,application,data,presentation}`, общее в `lib/src/core/`, точка сборки и навигация в `lib/src/app/`. Публичный API пакета экспортируется одним файлом `lib/<пакет>.dart`, детали лежат в `lib/src/`.
- State management и DI: `docs/adr/0003-state-management-and-di.md`. Коротко: держатели состояния экранов — `Cubit`/`Bloc` (`flutter_bloc`) с `sealed`-состояниями; зависимости только через конструкторы, сценарии собирает `AppDependencies` в точке сборки, держатели создаются на уровне маршрута (`go_router`, `lib/src/app/router/`). Экраны не знают о маршрутах и других фичах: переходы приходят колбэками.
- Партия: `docs/adr/0006-match-session.md`. Экран партии работает только со столом `MatchTable` (`lib/src/features/match/domain/`), не с движком и не с ботом: так hot-seat, бот и сеть подключаются одинаково.
- Поле и выборы в ходе: `docs/adr/0010-field-screen.md`. Экран поля (`lib/src/features/match/presentation/field/`) рисует проекцию `PlayerView`, цели хода считает `PlayTargets`, выбор игрока (карта, листы, тосты) держит `FieldCubit`, а не `MatchBloc`; геометрию зон берут из `FieldGeometry`, не из чисел в вёрстке. Старт партии, баннеры, итоги, пауза и главное меню: `docs/adr/0011-match-flow.md` (состояния `MatchBloc`, `HandoverKind`, `MenuCubit`); выбор фракции, лидера и колоды перед партией: `docs/adr/0012-faction-leader-deck-select.md` (`MatchSetupCubit`, экраны в `presentation/setup/`, лидер партии заменяет лидера колоды). Уровни сложности бота: `docs/adr/0021-bot-difficulty.md` (`BotDifficulty` и `GreedyBotSettings.forDifficulty` в `gwent_ai`, шаг сложности в `MatchSetupCubit` только против бота, уровень запоминается в настройках; фракцию бота выбирает случайно, а колоду собирает под уровень `ChooseOpponentDeck` с `BotDeckBuilder`, сид даёт `SeedGenerator`; колода бота живёт в `LocalMatchRequest.opponentDeck` и в хранилище не попадает). Ход после анимаций, конец партии, рука и безопасные зоны: `docs/adr/0013-match-pacing.md` (очередь состояний в `MatchScreen`, `FieldState.isBusy`; фон на весь экран, содержимое в `SafeArea`: `StartBackdrop` и `ScreenBackdrop` делают это сами). Список колод и конструктор (макет 8): тот же ADR 0012, вторая часть (`DeckListCubit`, `DeckEditorCubit`, маршруты `/decks`, `/decks/new`, `/decks/:id`; правила сборки в `DeckRules` и `DeckDraft`, экран только показывает; колоду без лидера сохранить нельзя; в лобби конструктор встроен через `banner` и `actionsBuilder`, ADR 0019).
- Экраны маршрутов и шапка «Назад»: `docs/adr/0016-screen-header-and-material.md`. Корень экрана маршрута — `Scaffold` или `ScreenBackdrop` (он даёт прозрачный `Material`); без `Material` весь текст получает отладочный стиль `MaterialApp` (жёлтое двойное подчёркивание), а оборачивать маршрут или `MaterialApp` в `Material` задним числом нельзя. Диалог подтверждения (`showConfirmDialog`) ставит кнопки в ряд, пока подписи влезают, иначе столбиком на всю ширину: подпись кнопки не переносится по буквам. Оверлеи поверх маршрута (просмотр карты и т. п.) открывают через `showGwentOverlay` (`core/presentation/components/gwent_overlay.dart`), он даёт `Material`; `showGeneralDialog` напрямую не вызывать (`showDialog` с `Dialog` в `builder` и `showModalBottomSheet` `Material` получают от `Dialog` и `BottomSheet`). Тест оверлея вызывает `expectNoFallbackTextStyle` с открытым оверлеем. Везде, где есть стрелка «Назад», шапка — `ScreenHeader` (`core/presentation/components/`): стрелка у левого края с полем 16 pt, заголовок по центру; своих `Row` со стрелкой не собирать. Тесты экранов кладут экран в `localizedScreen` (без `Scaffold`, как `go_router`) и вызывают `expectNoFallbackTextStyle` и `expectBackButtonAtEdge` из `test/support/screen_guards.dart`.
- Анимации розыгрыша карт и эффектов (макет 12): `docs/adr/0017-card-animations.md`. Показ строится из двух проекций и событий (`StageScriptBuilder` в `presentation/stage/`), идёт одним тикером (`StageHost`) и держит `FieldState.isBusy`, поэтому ход игрока, бота и сетевого соперника показываются одинаково; цифры прокручивает `RollingNumber`; скорость и «Уменьшить движение» учитываются при сборке сценария.
- Анимации конца раунда и матча (макет 13): `docs/adr/0018-round-animations.md`. Поле раунда (`MatchInProgress.closing`) собирает `MatchBloc`, сценарий `StageScriptBuilder.buildRound` строит шаги (подсчёт, плашка, камень, сброс, перки фракций); без `closing` остаётся лист итога из ADR 0011; «Пропустить» идёт по `script.steps`, плашки в `script.locks` тап не ускоряет. Итог матча — лист поверх поля (`MatchResultView(field: FieldView(readOnly: true))`, «Показать поле»/«К итогам»); в hot-seat конец раунда видит тот, кто его закончил, а «Передайте телефон» ждёт конца плашки хода.
- Игра на двух телефонах по Wi-Fi (макет 9): `docs/adr/0019-wifi-multiplayer.md`. Одна сетевая партия живёт в `NetworkGame` (`lobby/application/`), её держит `ActiveNetworkGame`; экраны лобби (`lobby/presentation/`) подписываются на неё через `RoomCubit`, а партия идёт через `NetworkMatchTable` и `MatchBloc(awaitingSession: true)`. Отсчёт перед стартом ведёт хост. Связь посреди партии (`MatchConnectionCubit`: индикатор в полосе соперника `MatchConnectionIndicator` через `opponentStatus` у `MatchScreen`, окно обрыва — слой `overlay`), сдача и выход соперника — второй PR; QR, экраны ошибок 7c–7e, экран 6c и янтарное «нестабильно»: ADR 0020 (`NetworkReadiness`, `QrScanScreen`, `HostQrScreen`, `OpponentPresence.unstable/away`). Защита от враждебного соперника: `docs/adr/0022-network-hardening.md` (лимит сообщения в `LanServer`/`CappedSocket` без сжатия, лимиты повторов в `MatchHost`, очистка имён в кодеке, гость проверяет данные хоста через `MatchClient(catalog:)`; новые транспорты проходят те же проверки; хост принимает гостя сам: `HostSettings.requireAdmission`, `MatchHost.admit/decline`, `RoomAdmission`).
- Игра через интернет, экраны (после ADR 0025 и 0026): `docs/adr/0027-online-screens.md`. Способ «Через интернет» выбирают на `PlayMethodScreen`; хост (`CreateOnlineGameScreen`) сразу получает комнату и видит код в `OnlineRoomWaiting`, гость вводит код в `JoinOnlineGameScreen`; комната та же `RoomScreen(online: true)`, тексты по `NoticeLink`. Код хоста читает `RoomCodeCubit` (он меняется, когда комната создаётся заново для нового гостя).
- Хвосты сети и реванш: `docs/adr/0028-network-tails-and-rematch.md`. Версия протокола 2 (`protocolVersion` в `gwent_net`; при несовпадении `JoinRefused(protocolMismatch)` и «Обновите приложение»), реванш по сети (`rematch_request`/`rematch_status`/`rematch_start`, окно 30 с у хоста, `RematchTable` и `RematchOffer` у стола, `MatchRematchAgreed` ведёт в комнату), место гостя в Supabase освобождает `confirm_guest` и `guest_seat_free` (миграция применяется пользователем перед раздачей сборки), лимит сообщения и у гостя (`LanConnector`), имя соперника в `MatchRoster.opponentName`.
- Рог и Мардрём в занятый слот: `docs/adr/0030-horn-in-occupied-slot.md` (играются, карта уходит в отбой; `engineVersion` 2 отделяет несовместимые правила).
- История партий и реплей: `docs/adr/0029-history-and-replay.md`. Сводки в `match_records`, реплей в `match_replays` (журнал `gwent_net` у бота, hot-seat и хоста, кадры проекций `FramesReplayLog` у гостя сети; `has_replay` в списке), запись при конце партии через `ReplayRecorder` в `MatchSession` (сеть: `NetworkReplayRecorder` в `NetworkGame`, журнал хоста снимается до сброса на реванш); `LoadReplay` проигрывает журнал текущим пакетом и открывает реплей, только если итог и счёт те же; показ — `ReplayCubit` на настоящем `FieldView(readOnly: true)` (фича `lib/src/features/replay/`, список — `match_history/presentation/`, маршруты `/history`, `/history/:id`).
- Экран настроек (макет 10): `docs/adr/0015-settings-screen.md`. `SettingsCubit` держит настройки у себя и пишет их в `SettingsRepository` (Drift) сразу; настройки без готовой функции (подтверждение паса) только сохраняются, подсказки показывают строку в центральной полосе выбора карты (ADR 0010), имя в сети видит соперник (ADR 0028), а громкость управляет звуком и музыкой (ADR 0023); скорость анимаций управляет анимациями карт (ADR 0017). Проверку обновления набора карт делает `CheckContentUpdate`, версии собирает `LoadAboutInfo`.
- Звук и музыка (ADR 0023): `lib/src/features/sound/`. Эффекты и композиции — перечисления `SoundEffect`/`MusicTrack` в domain, воспроизведение за интерфейсами `SoundOutput`/`MusicOutput` (реализации на `audioplayers` в data), громкость из настроек применяют `PlaySound` и `BackgroundMusic`. Звуки партии лежат в `StageScript.cues` и играет их `StageHost`; остальные держатели получают `PlaySound` необязательным параметром конструктора. Файлы — AAC (`.m4a`) в `assets/sfx/` и `assets/music/`, переводятся скриптами `tools/audio/`, происхождение и лицензия описаны в `tools/audio/README.md`. Новый эффект: значение в `SoundEffect`, файл, строка в `AudioplayersSoundOutput.fileName`, место в сценарии или держателе; тест `sound_assets_test.dart` сверяет файлы с перечислениями.
- Вибрация (ADR 0031): `lib/src/features/haptics/`. Паттерны — `HapticPattern` в domain, вывод за `HapticOutput` (реализация на `HapticFeedback` в data), выключатель «Вибрация» из настроек применяет `PlayHaptic`. Событие партии вибрирует вместе со своим звуком: паттерн события задаёт `SoundEffect.haptic` (`SoundHaptics`), подаёт `PlaySound(haptic:)`; новый звук = строка в `SoundHaptics`. Вибрацию прицеливания (`TargetHaptics`) подаёт `FieldCubit.vibrate`. Прицеливание, подсветка целей и карта под пальцем: ADR 0010, макет 14.
- Игра через интернет (Supabase): `docs/adr/0025-online-play-supabase-backend.md`. Телефон-хост остаётся хостом партии, Supabase Realtime пересылает кадры `Transport` в приватном канале `room:<id>`, комнаты и вход по коду живут в SQL-функциях `supabase/migrations/`; сессия `supabase_flutter` хранится в Drift, а не в `shared_preferences`. Тесты SQL: `tools/scripts/test_supabase.sh` (нужен `psql` и PostgreSQL, в CI задача `supabase`).
- Клиент игры через интернет (ADR 0026): `OnlineLobby` реализует `GameLobby` поверх приватного канала комнаты (`lobby/data/online/`), пакет `supabase` без `supabase_flutter`, сессия в Drift через `OnlineSessionStore`. Хост и гость входят теми же `HostNetworkGame`/`JoinNetworkGame` (`AppDependencies.hostOnlineGame`/`joinOnlineGame`) с `LinkTimings.internet`; адрес партии `OnlineAddress(RoomCode)`, для нового гостя хост пересоздаёт комнату, поэтому код читают заново через `NetworkGame.address()`. Тесты на `FakeOnlineServer` и локальном сервере `FakeSupabaseServer`, в облако они не ходят.
- Направление зависимостей между слоями проверяет `test/architecture_test.dart`.
- Best practice: SOLID; неизменяемые модели (`final`, `const`, `copyWith`); состояния, действия и события как `sealed`-классы с исчерпывающим `switch`; ошибки домена типизированы и ловятся по типу (`on`), без пустых `catch`; никаких глобальных синглтонов вне точки сборки; одна ответственность на класс и файл.

## Структура

| Путь | Что | Ограничения |
|---|---|---|
| `packages/gwent_engine` | движок правил | чистый Dart: без Flutter, `dart:io`, `dart:ui`, `DateTime.now()` и `Random()` без сида |
| `packages/gwent_ai` | ИИ-соперник (жадный бот, ADR 0004) | как у движка; ходы проверяет только движком |
| `packages/gwent_content` | пакет контента: модели, парсер, канонический JSON, хеш, валидатор | чистый Dart без Flutter и `dart:io`: данные приходят строками или байтами |
| `packages/gwent_net` | сетевой протокол: сообщения, кодек, хост и клиент партии, переподключение, журнал, транспорт в памяти (ADR 0005) | чистый Dart без Flutter и `dart:io`; реальные транспорты (Wi-Fi, BLE, сервер) реализуют `Transport` в слое data |
| `lib/`, `test/` | Flutter-приложение | зависит от пакетов через `path` |
| `lib/src/features/lobby/` | лобби сетевой игры: `GameLobby` в domain, Wi-Fi (mDNS через `bonsoir` + WebSocket `dart:io`) в data (ADR 0007), `NetworkGame` и сценарии в application, экраны макета 9 в presentation (ADR 0019) | тип сервиса `_gwent._tcp` совпадает с `NSBonjourServices` в `ios/Runner/Info.plist` |
| `docs/hand` | данные и правила (источник правды) | |
| `tools/` | утилиты проекта (Dart CLI вроде проверки данных и сборки пакета контента) | |
| `tools/build_pack` | сборка пакета контента из `docs/hand` и её тесты на настоящих данных | Dart CLI, в приложение не входит |
| `assets/content/` | собранный пакет контента для ассетов приложения | генерирует `setup.sh`, не коммитится |
| `tools/audio` | скрипты перевода звуков и музыки в AAC, список композиций, происхождение и лицензия файлов | коммитятся скрипты, результат лежит в `assets/sfx/` и `assets/music/` |
| `tools/app_icon` | иконка приложения: SVG-слои, PNG, скрипт растеризации; из PNG `setup.sh` собирает иконки iOS и Android | коммитятся и исходники, и результат в `ios/` и `android/` |
| `supabase/` | серверная часть игры через интернет: SQL-миграции Supabase (комнаты, функции, политики Realtime), тесты на PostgreSQL, ADR 0025 | отдельного репозитория нет; репозиторий открыт, секретов (secret-ключ, пароль базы) в нём и в CI нет; применённые миграции не редактируются, ошибка исправляется новым файлом; миграции к проекту применяет пользователь, см. `supabase/README.md` |
| `tools/scripts/setup.sh` | подготовка: зависимости и кодогенерация | единственное место для таких команд |
| `lib/src/core/database/` | база Drift пользовательских данных (`AppDatabase`, таблицы) | схема меняется только с новой версией, см. «Команды» |
| `drift_schemas/` | схемы базы всех версий для миграций | коммитятся, вручную не правятся |
| `lib/src/core/l10n/arb/` | строки интерфейса (ARB), шаблон `app_ru.arb` | вывод `gen-l10n` в `generated/` не коммитится |
| `.github/workflows/ci.yml` | CI: подготовка через `setup.sh`, формат, анализ, тесты | |

Ограничения пакетов проверяются тестами `test/purity_test.dart` в каждом пакете. Новый пакет в `packages/` или утилита в `tools/` добавляется и в матрицу `package` в `ci.yml`.

## Команды

Подготовка (зависимости и кодогенерация для пакетов и приложения), из корня:

```sh
tools/scripts/setup.sh                        # всё
tools/scripts/setup.sh packages/gwent_engine  # одна папка
```

Все команды подготовки и кодогенерации (`pub get`, `build_runner`, `gen-l10n` и любые новые) добавляются только в `tools/scripts/setup.sh`, а CI и разработчики вызывают этот скрипт. Скрипт должен работать в bash 3.2 (macOS). Новый генератор: добавить шаг в скрипт, проверить запуском и упомянуть в PR.

Изменение схемы базы: поправить таблицы в `lib/src/core/database/`, увеличить `schemaVersion`, запустить `setup.sh` (он сохранит схему новой версии в `drift_schemas/` и соберёт шаги `stepByStep`), дописать шаг миграции в `AppDatabase.migration` и закоммитить новый файл схемы. Если таблицы изменились без новой версии, `setup.sh` падает; в CI он падает и на незакоммиченном файле схемы. Пока файл схемы новой версии не попал в `dev`, его можно удалить и создать заново через `setup.sh`; файлы версий, уже попавших в `dev`, не меняются.

Миграции базы (`docs/adr/0024-database-migrations.md`): приложение ставится поверх старой сборки без удаления, поэтому данные игрока при обновлении не теряются. Любое изменение хранения (таблицы, колонки, настройки `build.yaml` про формат значений) = новая `schemaVersion`, шаг `stepByStep`, файл схемы и тест, который кладёт строки в базу прежней версии и проверяет их после миграции (`migrateAndValidate` одна не годится). Схема версии, попавшей в `dev`, не редактируется и не пересоздаётся (исключение: смена формата при обновлении `drift_dev`, отдельным PR); `destructiveFallback` и удаление базы при ошибке запрещены; шаг не вызывает код приложения. Тест данных пишется до шага. Транзакцию на `onUpgrade` и `onCreate` держит `AppDatabase`; CI на PR запускает `tools/scripts/check_schemas_immutable.sh`: он падает на изменении или удалении файла схемы, уже попавшего в базовую ветку. Откатов на старую сборку не бывает, их не обрабатываем. В описании PR с миграцией сказать, какие данные она затрагивает.

Сгенерированный код (`*.g.dart`, `*.freezed.dart` и т. п.) не коммитится: его создаёт `setup.sh` после каждого `git pull` и перед проверками. Скрипт сам приводит его к ширине строки проекта, чтобы не падала проверка формата. Вывод `gen-l10n` (`lib/src/core/l10n/generated/`), шаги миграций (`*.steps.dart`) и тестовые схемы базы (`test/drift/*/generated/`) тоже генерируются и лежат в `.gitignore`.

Проверки пакетов и утилит из `tools/` (достаточно Dart SDK 3.11.0, Flutter не нужен), из папки пакета:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

Проверки всего репозитория (Flutter 3.41.0, как в `.metadata` и в CI), из корня, после полного `setup.sh`:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos   # приложение, packages/ и tools/
flutter test                    # тесты приложения; тесты пакетов запускаются из их папок
```

CI запускает ровно эти команды; PR с красным CI не передаётся пользователю.

Код проверяется только этими командами `dart`/`flutter`: `format`, `analyze`, `test`. Никакой ручной проверки линтинга: не перечитывать код на соответствие правилам линтера и не писать для этого свои скрипты или grep. Архитектурные тесты вроде `purity_test.dart` это не проверка линтинга: они запускаются тем же `dart test` и разрешены. Ревьюер берёт замечания по стилю и линтингу только из вывода этих команд, а сам смотрит на логику, архитектуру и тесты.

### Линтер

- Один общий `analysis_options.yaml` в корне: строгий анализатор и явный список правил (ширина строки 120, `trailing_commas: preserve`). Пакеты в `packages/` подключают его строкой `include: ../../analysis_options.yaml`; своих правил у пакетов нет.
- Предупреждения и info считаются ошибками (`--fatal-infos`).
- `// ignore:` только с объяснением в том же комментарии (`document_ignores`). Отключать или добавлять правила глобально только по решению пользователя.

## Правила кода

- Движок детерминирован. Контракт по сетевой спецификации: `apply(state, seat, intent) → Result<(state, events), Reject>` и `project(state, seat) → PlayerView`; точная форма фиксируется ADR сети. Случайность только через переданный генератор с сидом. Одинаковый сид и одинаковые намерения дают одинаковую партию.
- По сети передаются действия (намерения), а не состояние. Скрытая информация (рука соперника, порядок колод) не попадает в проекцию другого игрока.
- Логика способностей живёт в коде движка; параметры (сила, ряд, количество, группы) живут в пакете контента. Исполняемую логику не скачивать.
- Пользовательские данные (колоды, история матчей, прогресс, настройки, метаданные и состояние скачанных наборов) хранятся в Drift. Сами пакеты контента хранятся неизменяемыми файлами в кэше, не в БД. `shared_preferences` только как исключение для мелких флагов, нужных до открытия БД.
- Строки интерфейса не зашиваются в код: только через локализацию Flutter (`gen-l10n`, ARB). Тексты карт берутся из строк пакета контента. Сейчас один язык, `ru`.
- Сеть по порядку: Wi-Fi (mDNS + WebSocket), затем Bluetooth LE, затем сервер.
- Фракция по умолчанию для первой играбельной версии и тестов: Скеллиге.
- Сначала тест, потом код. Найденный баг сначала превращается в падающий тест.

## Git и процесс

- Ветки `main` и `dev`. Прямые пуши в них запрещены. Любое изменение кода уходит через pull request в `dev`.
- Задачи создаёт только оркестратор (координатор проекта); каждая задача ведётся в своём треде.
- Имя ветки `task/*`, `feature/*` или `bug/*`; тип выбирает оркестратор (координатор проекта) и указывает в задаче.
- На каждый PR отдельный агент-ревьюер делает review; исполнитель исправляет замечания и доводит CI до зелёного.
- Версии и release notes: `CHANGELOG.md` в формате Keep a Changelog, по-русски, для игрока. Каждый PR с видимым игроку изменением добавляет строку в раздел «Не выпущено» (группы «Добавлено», «Изменено», «Исправлено», при необходимости остальные группы Keep a Changelog); рефакторинги, тесты и документация строк не добавляют. При выпуске отдельный PR в `dev` переносит раздел под номер версии с датой и ставит в `pubspec.yaml` `version: X.Y.Z+N` (N — номер сборки, растёт на 1 с каждым выпуском), затем PR `dev → main` мержит пользователь, и на получившийся коммит `main` ставится тег `vX.Y.Z` и создаётся GitHub Release с текстом раздела. Выпуск делается только по слову пользователя.
- Каждый PR запускает CI на GitHub, и он должен быть зелёным на последнем коммите ветки. Исполнитель проверяет прогон через GitHub (`get_check_runs`), передаёт PR пользователю только с зелёным CI и пишет об этом в сообщении. Если CI не запустился, исполнитель выясняет причину, а не передаёт PR без прогона.
- Агенты никогда не мержат и не аппрувят. Аппрув и мерж делает пользователь. Выпуск в `main` идёт PR `dev → main`.

## Отладка и сборка

- `.mcp.json` подключает Dart and Flutter MCP server (`dart mcp-server`, Dart 3.9+). На Mac через Remote Control он даёт `launch_app`, `hot_reload`, `get_runtime_errors`, `widget_inspector` и другие инструменты. Сервер и все его инструменты разрешены без подтверждения в `.claude/settings.json` (решение пользователя).
- Скриншот iOS-симулятора: `xcrun simctl io booted screenshot shot.png`.
- `flutter run`, симулятор, сборка iOS и проверка Bluetooth выполняются на Mac пользователя. Движок, пакет контента и их тесты работают в облаке с одним Dart SDK.
- Приложение не публикуется в сторах: Android APK (`flutter build apk --release`), iOS Ad Hoc под корпоративным аккаунтом.
