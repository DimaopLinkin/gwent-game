import 'dart:collection';

import 'package:gwent_net/src/protocol/envelope.dart';
import 'package:gwent_net/src/protocol/net_message.dart';

/// Что делать с принятым конвертом.
enum Delivery {
  /// Служебное сообщение: обработать сразу.
  control,

  /// Следующее по номеру: обработать.
  next,

  /// Уже принято раньше: пропустить.
  duplicate,

  /// Перед ним что-то потерялось: пропустить и попросить переотправку.
  gap,
}

/// Нумерация сообщений одной стороны соединения: что отправлено, что подтверждено собеседником, что принято.
///
/// Канал переживает обрывы: неподтверждённые сообщения хранятся до `ack` собеседника и уходят снова
/// после переподключения или по `resend`. Ввода-вывода здесь нет, только счётчики.
final class SequencedChannel {
  SequencedChannel({this.matchId});

  /// Партия, которую канал подписывает в исходящих конвертах.
  String? matchId;

  int _sent = 0;
  int _received = 0;
  int _resendAskedAt = -1;
  final Queue<Envelope> _unacked = Queue<Envelope>();

  /// Номер последнего отправленного сообщения.
  int get sent => _sent;

  /// Номер последнего сообщения собеседника, принятого без пропусков.
  int get received => _received;

  /// Есть сообщения, которые собеседник ещё не подтвердил.
  bool get hasUnacked => _unacked.isNotEmpty;

  /// Сколько сообщений собеседник ещё не подтвердил.
  int get unackedCount => _unacked.length;

  /// Сообщение с номером; хранится до подтверждения.
  Envelope sequenced(NetMessage message) {
    final envelope = Envelope(message, seq: ++_sent, ack: _received, matchId: matchId);
    _unacked.add(envelope);
    return envelope;
  }

  /// Служебное сообщение без номера.
  Envelope control(ControlMessage message) => Envelope(message, ack: _received, matchId: matchId);

  /// Учитывает подтверждение из конверта и решает, что делать с самим сообщением.
  Delivery receive(Envelope envelope) {
    acknowledge(envelope.ack);
    if (envelope.seq == 0) return Delivery.control;
    if (envelope.seq <= _received) return Delivery.duplicate;
    if (envelope.seq > _received + 1) return Delivery.gap;
    _received = envelope.seq;
    return Delivery.next;
  }

  /// Можно ли попросить переотправку после пропуска. Просим один раз на каждый принятый номер, чтобы поток
  /// сообщений после одной потери не вызвал поток переотправок; если просьба потеряется, её повторит
  /// проверка связи.
  bool claimResendRequest() {
    if (_resendAskedAt == _received) return false;
    _resendAskedAt = _received;
    return true;
  }

  /// Собеседник получил всё до [ack] включительно.
  void acknowledge(int ack) {
    while (_unacked.isNotEmpty && _unacked.first.seq <= ack) {
      _unacked.removeFirst();
    }
  }

  /// Неподтверждённые сообщения для переотправки, со свежим `ack`.
  List<Envelope> pending() => [
    for (final envelope in _unacked) Envelope(envelope.message, seq: envelope.seq, ack: _received, matchId: matchId),
  ];

  /// Можно ли дослать собеседнику всё после [ack]: сообщения после него ещё хранятся.
  bool canResumeFrom(int ack) => ack <= _sent && ack >= _sent - _unacked.length;

  /// Собеседник начнёт со снимка: неподтверждённое досылать не нужно.
  void discardUnacked() => _unacked.clear();

  /// Следующим ждём сообщение [next]: собеседник начал нумерацию заново или перешёл к снимку.
  void expectNext(int next) => _received = next - 1;

  /// Нумерация начинается после [ack]: собеседник уже принял столько сообщений этого места от прежнего
  /// экземпляра клиента (перезапуск с билетом). Вызывается до первого номерного сообщения.
  void startAfter(int ack) {
    if (_sent != 0) throw StateError('Нумерация уже начата: отправлено $_sent');
    _sent = ack;
  }
}
