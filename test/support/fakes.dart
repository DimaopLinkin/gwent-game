import 'dart:async';

import 'package:gwent/src/core/domain/app_info.dart';
import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/core/domain/seed_generator.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/haptics/domain/haptic_output.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/match_history/domain/replay_log.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';
import 'package:gwent/src/features/sound/domain/music_output.dart';
import 'package:gwent/src/features/sound/domain/music_track.dart';
import 'package:gwent/src/features/sound/domain/sound_effect.dart';
import 'package:gwent/src/features/sound/domain/sound_output.dart';
import 'package:gwent_ai/gwent_ai.dart';
import 'package:gwent_engine/gwent_engine.dart' show CardCatalog, MatchEngine;

/// Версия приложения, заданная тестом.
final class FakeAppInfo implements AppInfo {
  const FakeAppInfo([this.current = '1.0.0', this.build = '1']);

  final String current;
  final String build;

  @override
  Future<String> version() async => current;

  @override
  Future<String> buildNumber() async => build;
}

/// Часы, которые показывают заданное время.
final class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

/// Идентификаторы `id-1`, `id-2`, ...
final class SequentialIdGenerator implements IdGenerator {
  int _last = 0;

  @override
  String next() => 'id-${++_last}';
}

/// Сиды по порядку, начиная с заданного: партии в тестах воспроизводимы.
final class FixedSeedGenerator implements SeedGenerator {
  FixedSeedGenerator(this._next);

  int _next;

  @override
  int next() => _next++;
}

/// Колоды в памяти. Поток сразу выдаёт текущий список, как и реализация на Drift.
final class InMemoryDeckRepository implements DeckRepository {
  InMemoryDeckRepository([Iterable<Deck> decks = const []]) : _decks = {for (final deck in decks) deck.id: deck};

  final Map<String, Deck> _decks;
  final Map<String, String> _active = {};
  final StreamController<void> _changes = StreamController.broadcast();

  /// Ошибка, с которой падает [watchAll]; `null` — без ошибки.
  Exception? watchError;

  /// Ошибка, с которой [watchAll] падает сразу, а не в потоке; `null` — без ошибки.
  Error? watchThrows;

  /// Ошибка, с которой падает [save]; `null` — без ошибки.
  Error? saveError;

  /// Чтения отдают снимок и уступают очередь событий, как запросы к настоящей базе: так одновременные сценарии
  /// перемежаются и видят устаревшие данные.
  bool yieldOnRead = false;

  Future<void> _read() async {
    if (yieldOnRead) await Future<void>(() {});
  }

  /// Порядок как у Drift: сначала недавно изменённые, при равном времени по идентификатору.
  List<Deck> get _sorted => _decks.values.toList()
    ..sort(
      (a, b) => switch (b.updatedAt.compareTo(a.updatedAt)) {
        0 => a.id.compareTo(b.id),
        final order => order,
      },
    );

  @override
  Stream<List<Deck>> watchAll() => switch (watchError) {
    _ when watchThrows != null => throw watchThrows!,
    final error? => Stream.error(error),
    null => _watch(_changes, () => _sorted),
  };

  @override
  Future<List<Deck>> findByFaction(String factionId) async {
    final decks = _sorted.where((deck) => deck.factionId == factionId).toList();
    await _read();
    return decks;
  }

  @override
  Future<Deck?> findById(String id) async => _decks[id];

  @override
  Future<void> save(Deck deck, {bool activate = false}) async {
    if (saveError case final error?) throw error;
    _decks[deck.id] = deck;
    _active.removeWhere((factionId, deckId) => deckId == deck.id && factionId != deck.factionId);
    if (activate) _active[deck.factionId] = deck.id;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _decks.remove(id);
    _active.removeWhere((_, deckId) => deckId == id);
    _changes.add(null);
  }

  @override
  Stream<Map<String, String>> watchActiveDeckIds() => _watch(_changes, () => Map.of(_active));

  @override
  Future<String?> findActiveDeckId(String factionId) async {
    final deckId = _active[factionId];
    await _read();
    return deckId;
  }

  @override
  Future<void> setActive(String deckId) async {
    final deck = _decks[deckId] ?? (throw DeckNotFoundException(deckId));
    _active[deck.factionId] = deck.id;
    _changes.add(null);
  }
}

/// Настройки в памяти. Поток сразу выдаёт текущие настройки и новые после каждого сохранения.
base class InMemorySettingsRepository implements SettingsRepository {
  final StreamController<void> _changes = StreamController.broadcast();

  AppSettings saved = const AppSettings();

  @override
  Stream<AppSettings> watch() => _watch(_changes, () => saved);

  @override
  Future<void> save(AppSettings settings) async {
    saved = settings;
    _changes.add(null);
  }
}

/// История партий в памяти. Поток сразу выдаёт историю и новую после каждой записи.
final class InMemoryMatchHistoryRepository implements MatchHistoryRepository {
  final StreamController<void> _changes = StreamController.broadcast();

  /// Партии в порядке записи.
  final List<MatchRecord> records = [];

  /// Порядок как у Drift: сначала последние, при равном времени по идентификатору.
  List<MatchRecord> get _sorted => List.of(records)
    ..sort(
      (a, b) => switch (b.finishedAt.compareTo(a.finishedAt)) {
        0 => a.id.compareTo(b.id),
        final order => order,
      },
    );

  @override
  Stream<List<MatchRecord>> watchAll() => _watch(_changes, () => _sorted);

  /// Реплеи по идентификаторам партий.
  final Map<String, ReplayLog> replays = {};

  @override
  Future<MatchRecord?> findById(String id) async => records.where((record) => record.id == id).firstOrNull;

  @override
  Future<void> add(MatchRecord record, {ReplayLog? replay}) async {
    records.add(record);
    if (replay != null) replays[record.id] = replay;
    _changes.add(null);
  }

  @override
  Future<ReplayLog?> findReplay(String recordId) async => replays[recordId];
}

/// Поток, который сразу выдаёт [read] и повторяет его после каждого события [changes].
Stream<T> _watch<T>(StreamController<void> changes, T Function() read) => Stream.multi((controller) {
  controller.add(read());
  final subscription = changes.stream.listen((_) => controller.add(read()));
  controller.onCancel = subscription.cancel;
});

/// Жадный бот нормального уровня без ошибок: для тестов, где важен ход партии, а не уровень сложности.
MatchBot plainGreedyBot(MatchEngine engine, CardCatalog catalog, BotDifficulty difficulty, int seed) =>
    GreedyBot(engine, catalog);

/// Вывод звука, который ничего не играет, а запоминает запуски: для проверки, какие эффекты и с какой громкостью
/// должны были прозвучать.
final class RecordingSoundOutput implements SoundOutput {
  /// Запуски в порядке вызова.
  final List<({SoundEffect effect, double volume})> played = [];

  /// Сколько раз просили подготовить эффекты.
  int preloads = 0;

  /// Эффекты, которые прозвучали, в порядке вызова.
  List<SoundEffect> get effects => [for (final entry in played) entry.effect];

  @override
  Future<void> preload() async => preloads++;

  @override
  void play(SoundEffect effect, {required double volume}) => played.add((effect: effect, volume: volume));
}

/// Вывод вибрации, который ничего не подаёт, а запоминает паттерны по порядку вызова.
final class RecordingHapticOutput implements HapticOutput {
  /// Паттерны в порядке вызова.
  final List<HapticPattern> played = [];

  @override
  void play(HapticPattern pattern) => played.add(pattern);
}

/// Вывод музыки, который ничего не играет, а запоминает команды.
final class FakeMusicOutput implements MusicOutput {
  final StreamController<void> _ended = StreamController<void>.broadcast();

  /// Команды в порядке вызова: `play:<композиция>`, `volume:<громкость>`, `pause`, `resume`.
  final List<String> commands = [];

  /// Композиции, которые запускались, в порядке вызова.
  List<MusicTrack> get tracks => [
    for (final command in commands)
      if (command.startsWith('play:')) MusicTrack.values.byName(command.substring(5)),
  ];

  /// Удаётся ли запустить композицию.
  bool playSucceeds = true;

  /// Сколько длится каждая команда: так видно, что команды не перемежаются, как у настоящего проигрывателя.
  Duration commandDuration = Duration.zero;

  Future<void> _takeTime() =>
      commandDuration == Duration.zero ? Future<void>.value() : Future<void>.delayed(commandDuration);

  /// Композиция доиграла до конца.
  void finishTrack() => _ended.add(null);

  @override
  Stream<void> get trackEnded => _ended.stream;

  @override
  Future<bool> play(MusicTrack track, {required double volume}) async {
    await _takeTime();
    commands
      ..add('play:${track.name}')
      ..add('volume:$volume');
    return playSucceeds;
  }

  @override
  Future<void> setVolume(double volume) async {
    await _takeTime();
    commands.add('volume:$volume');
  }

  @override
  Future<void> pause() async {
    await _takeTime();
    commands.add('pause');
  }

  @override
  Future<void> resume() async {
    await _takeTime();
    commands.add('resume');
  }
}
