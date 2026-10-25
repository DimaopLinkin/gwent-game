import 'package:meta/meta.dart';

/// Как идёт предложение реванша после сетевой партии (ADR 0028).
enum RematchStage {
  /// Реванш никто не просил: игрок может предложить его.
  idle,

  /// Игрок предложил реванш и ждёт ответа соперника.
  requested,

  /// Соперник предложил реванш и ждёт ответа игрока.
  invited,

  /// Время на ответ вышло.
  expired,

  /// Соперник ушёл.
  opponentGone,
}

/// Предложение реванша, как его видит этот игрок: стадия и время на ответ.
@immutable
final class RematchOffer {
  /// Создаёт предложение. [window] — сколько хост даёт на ответ с момента, когда предложение стало [requested] или
  /// [invited].
  const RematchOffer(this.stage, {this.window = Duration.zero});

  /// Реванш ещё никто не просил.
  static const RematchOffer idle = RematchOffer(RematchStage.idle);

  /// Стадия.
  final RematchStage stage;

  /// Время на ответ; осмысленно при [RematchStage.requested] и [RematchStage.invited].
  final Duration window;

  /// Игрок может нажать «Реванш»: предложить его или согласиться на предложение соперника.
  bool get canRequest => stage == RematchStage.idle || stage == RematchStage.invited;

  /// Идёт отсчёт времени на ответ.
  bool get counting => stage == RematchStage.requested || stage == RematchStage.invited;

  @override
  bool operator ==(Object other) => other is RematchOffer && other.stage == stage && other.window == window;

  @override
  int get hashCode => Object.hash(stage, window);

  @override
  String toString() => 'RematchOffer(${stage.name}, $window)';
}
