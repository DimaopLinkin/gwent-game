import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:gwent/src/features/tutorial/application/start_first_match.dart';
import 'package:gwent/src/features/tutorial/presentation/first_match_state.dart';

/// Держатель экрана «Первой партии»: начинает партию по сценарию и начинает её заново по просьбе игрока.
///
/// Стол начатой партии закрывает держатель экрана партии (`MatchBloc`), который получает её через
/// `MatchSessionOpened`; сам держатель стол не трогает, пока не отдал его.
final class FirstMatchCubit extends Cubit<FirstMatchState> {
  /// Создаёт держатель и сразу начинает партию.
  FirstMatchCubit(this._start, {required this.playerDeckName, required this.opponentDeckName})
    : super(const FirstMatchLoading()) {
    unawaited(_begin());
  }

  final StartFirstMatch _start;

  /// Название колоды игрока на экране знакомства.
  final String playerDeckName;

  /// Название колоды соперника на экране знакомства.
  final String opponentDeckName;
  int _attempt = 0;

  /// Начинает партию с первого шага.
  Future<void> restart() async {
    emit(const FirstMatchLoading());
    _attempt++;
    await _begin();
  }

  Future<void> _begin() async {
    final attempt = _attempt;
    try {
      final result = await _start(playerDeckName: playerDeckName, opponentDeckName: opponentDeckName);
      switch (result) {
        case FirstMatchStarted(:final session, :final director):
          if (isClosed || attempt != _attempt) {
            // Экран ушёл раньше, чем партия началась: бот без экрана ходить не должен.
            await session.table.close();
            return;
          }
          emit(FirstMatchPlaying(session: session, director: director, attempt: attempt));
        case FirstMatchUnavailable():
          if (!isClosed) emit(const FirstMatchFailed());
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(const FirstMatchFailed());
    }
  }
}
