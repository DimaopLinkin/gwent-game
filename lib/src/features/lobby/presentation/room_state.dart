import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/lobby/domain/lobby_room.dart';
import 'package:meta/meta.dart';

/// Состояние экрана комнаты сетевой игры: что в комнате, какая колода выбрана и сколько осталось до старта.
@immutable
final class RoomState {
  /// Создаёт состояние.
  const RoomState({required this.room, this.rules, this.deck, this.issues = const [], this.countdownLeft});

  /// Комната: соперник, стадии, связь.
  final LobbyRoom room;

  /// Правила сборки колод: по ним проверяются колоды и называются фракции и лидеры. `null`, пока читаются или если
  /// набор карт не загрузился.
  final DeckRules? rules;

  /// Колода, с которой игрок идёт в партию; `null`, пока не выбрана.
  final Deck? deck;

  /// Нарушения правил в выбранной колоде. Пусто, если колода годится или не выбрана.
  final List<DeckIssue> issues;

  /// Секунд до начала партии; `null`, пока отсчёта нет.
  final int? countdownLeft;

  /// Выбранная колода годится для партии.
  bool get deckValid => deck != null && issues.isEmpty;

  /// Копия с заменёнными полями.
  RoomState copyWith({
    LobbyRoom? room,
    DeckRules? rules,
    Deck? deck,
    bool clearDeck = false,
    List<DeckIssue>? issues,
    int? countdownLeft,
    bool clearCountdown = false,
  }) => RoomState(
    room: room ?? this.room,
    rules: rules ?? this.rules,
    deck: clearDeck ? null : deck ?? this.deck,
    issues: clearDeck ? const [] : issues ?? this.issues,
    countdownLeft: clearCountdown ? null : countdownLeft ?? this.countdownLeft,
  );

  @override
  bool operator ==(Object other) =>
      other is RoomState &&
      other.room == room &&
      identical(other.rules, rules) &&
      other.deck == deck &&
      other.issues.length == issues.length &&
      other.countdownLeft == countdownLeft;

  @override
  int get hashCode => Object.hash(room, deck, issues.length, countdownLeft);
}
