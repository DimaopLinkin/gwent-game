import 'dart:async';

import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_exceptions.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_history_repository.dart';
import 'package:gwent/src/features/match_history/domain/match_record.dart';
import 'package:gwent/src/features/settings/domain/app_settings.dart';
import 'package:gwent/src/features/settings/domain/settings_repository.dart';

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

/// Колоды в памяти. Поток сразу выдаёт текущий список, как и реализация на Drift.
final class InMemoryDeckRepository implements DeckRepository {
  InMemoryDeckRepository([Iterable<Deck> decks = const []]) : _decks = {for (final deck in decks) deck.id: deck};

  final Map<String, Deck> _decks;
  final Map<String, String> _active = {};
  final StreamController<void> _changes = StreamController.broadcast();

  /// Ошибка, с которой падает [watchAll]; `null` — без ошибки.
  Exception? watchError;

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
final class InMemorySettingsRepository implements SettingsRepository {
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

  @override
  Future<void> add(MatchRecord record) async {
    records.add(record);
    _changes.add(null);
  }
}

/// Поток, который сразу выдаёт [read] и повторяет его после каждого события [changes].
Stream<T> _watch<T>(StreamController<void> changes, T Function() read) => Stream.multi((controller) {
  controller.add(read());
  final subscription = changes.stream.listen((_) => controller.add(read()));
  controller.onCancel = subscription.cancel;
});
