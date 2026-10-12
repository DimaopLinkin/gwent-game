import 'package:gwent_engine/gwent_engine.dart';

/// Ждёт ли партия действия от игрока, который видит проекцию [view]: выбора, пересдачи или хода.
///
/// По этому признаку экран понимает, кто сейчас держит телефон в hot-seat, и можно ли показывать игроку кнопки.
bool awaitsAction(PlayerView view) {
  if (view.choice != null) return true;
  return switch (view.phase) {
    MatchPhase.redraw => !view.me.redrawDone,
    MatchPhase.playing => view.turn == view.viewer && !view.me.passed,
    // Выбор Скоя'таэлей приходит полем `choice`; без него ждут соперника.
    MatchPhase.choosingFirstPlayer || MatchPhase.finished => false,
  };
}
