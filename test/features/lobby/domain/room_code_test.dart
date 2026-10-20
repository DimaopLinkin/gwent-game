import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/domain/game_address.dart';
import 'package:gwent/src/features/lobby/domain/room_code.dart';

void main() {
  test('код принимается в любом регистре, с пробелами и дефисами', () {
    for (final input in ['ABCDEF', 'abcdef', ' abc-def ', 'AbC DeF', 'a-b-c-d-e-f', 'ABC\tDEF']) {
      expect(RoomCode.tryParse(input)?.value, 'ABCDEF', reason: input);
    }
  });

  test('код показывается игроку с дефисом посередине', () {
    expect(RoomCode.tryParse('abcdef')!.formatted, 'ABC-DEF');
  });

  test('не код: не та длина и знаки вне алфавита, в том числе похожие 0, 1, I, O', () {
    for (final input in [
      '',
      'ABCDE',
      'ABCDEFG',
      'ABCDE0',
      'ABCDE1',
      'ABCDEI',
      'ABCDEO',
      'ABCDE!',
      'ABCDEЖ',
      'ß23456',
    ]) {
      expect(RoomCode.tryParse(input), isNull, reason: input);
    }
  });

  test('весь алфавит годится для кода', () {
    expect(RoomCode.alphabet.length, 32);
    final code = RoomCode.tryParse(RoomCode.alphabet.substring(0, RoomCode.length));
    expect(code, isNotNull);
  });

  test('адрес комнаты определяет код, равенство по коду', () {
    final address = OnlineAddress(RoomCode.tryParse('ABCDEF')!);
    expect(address.gameId, 'ABCDEF');
    expect(address, OnlineAddress(RoomCode.tryParse('abc-def')!));
    expect(address.hashCode, OnlineAddress(RoomCode.tryParse('abcdef')!).hashCode);
    expect(address, isNot(OnlineAddress(RoomCode.tryParse('ABCDEG')!)));
  });
}
