import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/game_invite.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';

void main() {
  test('приглашение переносит адрес партии строкой', () {
    final address = LanAddress(gameId: 'c0ffee-42', hosts: const ['192.168.1.5', '10.0.0.7'], port: 40123);
    final invite = GameInvite.encode(address);
    expect(invite, 'gwent://lan/c0ffee-42?p=40123&h=192.168.1.5&h=10.0.0.7');
    expect(GameInvite.decode(invite), address);
    expect(GameInvite.decode('  $invite\n'), address, reason: 'сканер может добавить пробелы');
  });

  test('приглашение в комнату через интернет несёт только код', () {
    final address = OnlineAddress(RoomCode.tryParse('abc-d2f')!);
    final invite = GameInvite.encode(address);
    expect(invite, 'gwent://online/ABCD2F');
    expect(GameInvite.decode(invite), address);
    expect(GameInvite.decode('gwent://online/abcd2f'), address, reason: 'регистр не важен');
  });

  test('чужие и битые строки не приглашение', () {
    for (final text in [
      '',
      'https://example.com',
      'gwent://ble/c0ffee?p=1&h=1.2.3.4',
      'gwent://lan/?p=1&h=1.2.3.4',
      'gwent://lan/g?h=1.2.3.4',
      'gwent://lan/g?p=0&h=1.2.3.4',
      'gwent://lan/g?p=70000&h=1.2.3.4',
      'gwent://lan/g?p=12',
      'gwent://lan/a/b?p=12&h=1.2.3.4',
      'gwent://online/',
      'gwent://online/ABC',
      'gwent://online/ABCDEI',
      'gwent://online/ABCDEF/G',
    ]) {
      expect(GameInvite.decode(text), isNull, reason: text);
    }
  });

  test('адрес без хостов или с плохим портом не создаётся', () {
    expect(() => LanAddress(gameId: 'g', hosts: const [], port: 1), throwsArgumentError);
    expect(() => LanAddress(gameId: 'g', hosts: const ['1.2.3.4'], port: 0), throwsArgumentError);
  });
}
