import 'package:gwent/src/features/deck_builder/domain/deck.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_issue.dart';
import 'package:gwent/src/features/deck_builder/domain/deck_rules.dart';
import 'package:gwent/src/features/deck_builder/domain/faction_info.dart';
import 'package:gwent/src/features/match/application/start_match.dart';
import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;
import 'package:gwent_engine/gwent_engine.dart' show Seat;
import 'package:meta/meta.dart';

/// Шаг выбора перед партией: сложность бота (ADR 0021), потом по макету 7 фракция и колода.
enum SetupStep {
  /// Уровень сложности бота; только против бота и только у первого места.
  difficulty,

  /// Карусель фракций.
  faction,

  /// Колоды выбранной фракции.
  deck,
}

/// Колода фракции в списке выбора и то, годится ли она в партию.
@immutable
final class DeckChoice {
  /// Создаёт строку списка.
  DeckChoice({required this.deck, required List<DeckIssue> issues}) : issues = List.unmodifiable(issues);

  /// Сохранённая колода.
  final Deck deck;

  /// Проблемы колоды; пусто, если с ней можно идти в партию.
  final List<DeckIssue> issues;

  /// Годится ли колода для партии.
  bool get ready => issues.isEmpty;
}

/// Состояние выбора фракции и колоды перед партией.
@immutable
sealed class MatchSetupState {
  const MatchSetupState();
}

/// Правила и колоды ещё читаются.
final class MatchSetupLoading extends MatchSetupState {
  /// Создаёт состояние.
  const MatchSetupLoading();
}

/// Правила или колоды прочитать не удалось.
final class MatchSetupFailed extends MatchSetupState {
  /// Создаёт состояние с причиной [error].
  const MatchSetupFailed(this.error);

  /// Причина для журнала; игроку показывается общее сообщение.
  final Object error;
}

/// Игрок выбирает: какое место, на каком шаге и что уже выбрано на нём.
final class MatchSetupReady extends MatchSetupState {
  /// Создаёт состояние.
  MatchSetupReady({
    required this.mode,
    required this.difficulty,
    required this.seat,
    required this.step,
    required this.rules,
    required this.factionIndex,
    required List<DeckChoice> decks,
    required this.deckId,
    required this.canStepBack,
    this.busy = false,
  }) : decks = List.unmodifiable(decks);

  /// Режим партии.
  final LocalMatchMode mode;

  /// Выбранный уровень сложности бота; в hot-seat не используется.
  final BotDifficulty difficulty;

  /// Место, за которое игрок выбирает: в hot-seat по очереди оба, против бота только первое.
  final Seat seat;

  /// Текущий шаг.
  final SetupStep step;

  /// Правила колод: пакет контента, фракции и лидеры.
  final DeckRules rules;

  /// Номер фракции среди [DeckRules.factionInfos].
  final int factionIndex;

  /// Колоды выбранной фракции, сначала недавно изменённые; заполнены на шаге колоды.
  final List<DeckChoice> decks;

  /// Идентификатор выбранной колоды; до шага колоды `null`.
  final String? deckId;

  /// Можно ли вернуться на предыдущий шаг внутри выбора (с первого шага первого места выход из выбора ведёт в меню).
  final bool canStepBack;

  /// Идёт сохранение выбора или подготовка колоды: кнопки шага не принимают повторных нажатий.
  final bool busy;

  /// Сколько шагов с подписью «Шаг N из M»: фракция и колода, а против бота ещё сложность.
  int get stepTotal => mode == LocalMatchMode.vsBot ? 3 : 2;

  /// Номер шага [step] для подписи «Шаг N из M»: против бота сложность занимает первый номер.
  int stepNumber(SetupStep step) => switch (step) {
    SetupStep.difficulty => 1,
    SetupStep.faction => mode == LocalMatchMode.vsBot ? 2 : 1,
    SetupStep.deck => mode == LocalMatchMode.vsBot ? 3 : 2,
  };

  /// Выбранная фракция.
  FactionInfo get faction => rules.factionInfos[factionIndex];

  /// Выбранная колода или `null`.
  DeckChoice? get selectedDeck {
    for (final choice in decks) {
      if (choice.deck.id == deckId) return choice;
    }
    return null;
  }

  /// Выбирает ли сейчас последнее место: после него партия начинается.
  bool get isLastSeat => mode == LocalMatchMode.vsBot || seat == Seat.two;

  /// Играют ли двое за одним телефоном: тогда над шагом подписано, чей он.
  bool get isHotSeat => mode == LocalMatchMode.hotSeat;
}

/// Выбор закончен: запрос на партию готов, экран передаёт его держателю партии.
final class MatchSetupDone extends MatchSetupState {
  /// Создаёт состояние.
  const MatchSetupDone(this.request);

  /// Запрос на партию.
  final LocalMatchRequest request;
}
