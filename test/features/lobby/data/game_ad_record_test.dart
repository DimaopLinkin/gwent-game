import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/lobby/data/game_ad_record.dart';
import 'package:gwent/src/features/lobby/domain/game_ad.dart';

import '../support/lobby_fakes.dart';

void main() {
  const ad = GameAd(id: '6f1c2d4e-0000-4000-8000-000000000001', hostName: 'Геральт', ruleset: testRuleset);

  test('объявление переживает TXT-запись', () {
    final attributes = GameAdRecord.encode(ad);
    expect(GameAdRecord.decode(attributes), ad);
    expect(GameAdRecord.decode(GameAdRecord.encode(ad.copyWith(open: false))), ad.copyWith(open: false));
    for (final MapEntry(:key, :value) in attributes.entries) {
      expect(utf8.encode('$key=$value').length, lessThanOrEqualTo(255), reason: key);
    }
  });

  test('длинное имя обрезается по целым символам', () {
    final name = 'Ведьмак 🐺' * 10;
    final decoded = GameAdRecord.decode(GameAdRecord.encode(ad.copyWith(hostName: name)))!;
    expect(utf8.encode(decoded.hostName).length, lessThanOrEqualTo(GameAdRecord.maxHostNameBytes));
    expect(name.startsWith(decoded.hostName), isTrue);
    expect(GameAdRecord.truncateUtf8('аб🐺', 7), 'аб', reason: 'волк занимает 4 байта и не влезает целиком');
    expect(GameAdRecord.truncateUtf8('аб🐺', 8), 'аб🐺');
  });

  test('чужая или битая запись не разбирается', () {
    final valid = GameAdRecord.encode(ad);
    expect(GameAdRecord.decode(const {'lib': 'bonsoir'}), isNull);
    for (final key in valid.keys) {
      expect(GameAdRecord.decode({...valid}..remove(key)), isNull, reason: 'нет $key');
    }
    expect(GameAdRecord.decode({...valid, 'v': 'один'}), isNull);
    expect(GameAdRecord.decode({...valid, 'o': 'yes'}), isNull);
    expect(GameAdRecord.decode({...valid, 'g': ''}), isNull);
  });
}
