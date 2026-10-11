import 'dart:async';

import 'package:gwent/src/core/domain/clock.dart';
import 'package:gwent/src/core/domain/id_generator.dart';
import 'package:gwent/src/features/deck_builder/domain/deck.dart';
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
  final StreamController<void> _changes = StreamController.broadcast();

  /// Ошибка, с которой падает [watchAll]; `null` — без ошибки.
  Exception? watchError;

  List<Deck> get _sorted => _decks.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<List<Deck>> watchAll() => Stream.multi((controller) {
    if (watchError case final error?) {
      controller
        ..addError(error)
        ..closeSync();
      return;
    }
    controller.add(_sorted);
    final changes = _changes.stream.listen((_) => controller.add(_sorted));
    controller.onCancel = changes.cancel;
  });

  @override
  Future<Deck?> findById(String id) async => _decks[id];

  @override
  Future<void> save(Deck deck) async {
    _decks[deck.id] = deck;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _decks.remove(id);
    _changes.add(null);
  }
}

/// Настройки в памяти.
final class InMemorySettingsRepository implements SettingsRepository {
  AppSettings saved = const AppSettings();

  @override
  Stream<AppSettings> watch() => Stream.value(saved);

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

/// История партий в памяти.
final class InMemoryMatchHistoryRepository implements MatchHistoryRepository {
  final List<MatchRecord> records = [];

  @override
  Stream<List<MatchRecord>> watchAll() => Stream.value(List.of(records.reversed));

  @override
  Future<void> add(MatchRecord record) async => records.add(record);
}
