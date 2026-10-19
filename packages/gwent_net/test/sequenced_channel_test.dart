import 'package:gwent_engine/gwent_engine.dart';
import 'package:gwent_net/gwent_net.dart';
import 'package:gwent_net/src/session/sequenced_channel.dart';
import 'package:test/test.dart';

void main() {
  const pass = IntentMessage(Pass());
  const online = OpponentPresence(online: true, name: 'Цири');

  Envelope from(int seq, {int ack = 0}) => Envelope(online, seq: seq, ack: ack);

  test('номера растут с 1, ack несёт последнее принятое без пропусков', () {
    final channel = SequencedChannel(matchId: 'm');
    expect(channel.receive(from(1)), Delivery.next);
    final first = channel.sequenced(pass);
    final second = channel.sequenced(pass);
    expect([first.seq, second.seq], [1, 2]);
    expect(second.ack, 1);
    expect(second.matchId, 'm');
    expect(channel.control(const ResendRequest()).seq, 0);
  });

  test('повтор пропускается, пропуск обнаруживается и просьба о переотправке не повторяется', () {
    final channel = SequencedChannel();
    expect(channel.receive(from(1)), Delivery.next);
    expect(channel.receive(from(1)), Delivery.duplicate);
    expect(channel.receive(from(3)), Delivery.gap);
    expect(channel.claimResendRequest(), isTrue);
    expect(channel.receive(from(4)), Delivery.gap);
    expect(channel.claimResendRequest(), isFalse);
    expect(channel.receive(from(2)), Delivery.next);
    expect(channel.receive(from(3)), Delivery.next);
    expect(channel.claimResendRequest(), isTrue);
    expect(channel.received, 3);
    expect(channel.receive(const Envelope(Ping(sent: 9))), Delivery.control);
  });

  test('подтверждённое удаляется, остальное переотправляется со свежим ack', () {
    final channel = SequencedChannel();
    for (var i = 0; i < 3; i++) {
      channel.sequenced(pass);
    }
    channel.receive(from(1, ack: 1));
    expect(channel.pending().map((envelope) => (envelope.seq, envelope.ack)), [(2, 1), (3, 1)]);
    expect(channel.canResumeFrom(1), isTrue);
    expect(channel.canResumeFrom(3), isTrue);
    expect(channel.canResumeFrom(0), isFalse, reason: 'первое сообщение уже подтверждено и удалено');
    expect(channel.canResumeFrom(4), isFalse, reason: 'собеседник получил больше, чем отправлено');
    channel.acknowledge(3);
    expect(channel.hasUnacked, isFalse);
  });

  test('нумерация может начаться после ack собеседника, но только до первого сообщения', () {
    final channel = SequencedChannel()..startAfter(5);
    expect(channel.sequenced(pass).seq, 6);
    expect(() => channel.startAfter(9), throwsStateError);
  });

  test('после снимка следующим ожидается указанный номер', () {
    final channel = SequencedChannel()..expectNext(10);
    expect(channel.receive(from(9)), Delivery.duplicate);
    expect(channel.receive(from(10)), Delivery.next);
  });
}
