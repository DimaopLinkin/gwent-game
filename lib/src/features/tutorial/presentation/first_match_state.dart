import 'package:gwent/src/features/match/domain/match_session.dart';
import 'package:gwent/src/features/tutorial/domain/scenario_director.dart';
import 'package:meta/meta.dart';

/// Состояние экрана «Первой партии».
@immutable
sealed class FirstMatchState {
  const FirstMatchState();
}

/// Партия готовится.
final class FirstMatchLoading extends FirstMatchState {
  /// Создаёт состояние.
  const FirstMatchLoading();
}

/// Партия начата: [session] идёт на столе, [director] ведёт сценарий; [attempt] растёт с каждым «Начать заново», чтобы
/// держатели экрана партии создавались заново.
final class FirstMatchPlaying extends FirstMatchState {
  /// Создаёт состояние.
  const FirstMatchPlaying({required this.session, required this.director, required this.attempt});

  /// Партия.
  final MatchSession session;

  /// Режиссёр сценария.
  final ScenarioDirector director;

  /// Номер попытки с нуля.
  final int attempt;
}

/// Партию начать не удалось.
final class FirstMatchFailed extends FirstMatchState {
  /// Создаёт состояние.
  const FirstMatchFailed();
}
