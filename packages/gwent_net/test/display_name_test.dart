import 'dart:convert';

import 'package:gwent_net/gwent_net.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Имена приходят от собеседника и попадают на экран и в историю: их приводят к безопасному виду на входе.
final String rtlOverride = String.fromCharCode(0x202e);
final String isolate = String.fromCharCode(0x2066);
final String isolateEnd = String.fromCharCode(0x2069);
final String zeroWidth = String.fromCharCode(0x200b);
final String bom = String.fromCharCode(0xfeff);

void main() {
  group('cleanDisplayName', () {
    test('обычное имя остаётся как есть', () {
      expect(cleanDisplayName('Геральт из Ривии'), 'Геральт из Ривии');
      expect(cleanDisplayName('Цири 🐺'), 'Цири 🐺');
    });

    test('управляющие знаки и знаки направления письма убираются', () {
      expect(cleanDisplayName('Ге\u0000ра\nльт\t'), 'Геральт');
      expect(
        cleanDisplayName([rtlOverride, 'тльareG'].join()),
        'тльareG',
        reason: 'RTL-подмена не должна переворачивать подпись',
      );
      expect(cleanDisplayName(['a', zeroWidth, 'b', isolate, 'c', isolateEnd, 'd', bom, 'е'].join()), 'abcdе');
    });

    test('составные эмодзи не рассыпаются, а имя из одних невидимых знаков пустое', () {
      final family = ['👨', String.fromCharCode(0x200d), '👩'].join();
      expect(cleanDisplayName(family), family);
      expect(cleanDisplayName([String.fromCharCode(0x3164), String.fromCharCode(0x2800), zeroWidth].join()), '');
    });

    test('пробелы по краям убираются, пустое имя остаётся пустым', () {
      expect(cleanDisplayName('  Йеннифэр  '), 'Йеннифэр');
      expect(cleanDisplayName('$rtlOverride\u0000 '), '');
    });

    test('длинное имя обрезается по целым символам до предела в байтах', () {
      final cleaned = cleanDisplayName('я' * 40000);
      expect(utf8.encode(cleaned).length, lessThanOrEqualTo(maxDisplayNameBytes));
      expect(cleaned, isNotEmpty);
      expect(truncateUtf8('аб🐺', 7), 'аб', reason: 'волк занимает 4 байта и не влезает целиком');
      expect(truncateUtf8('аб🐺', 8), 'аб🐺');
    });
  });

  test('имя из кадра приходит очищенным: и в hello, и в сообщении о сопернике', () {
    const codec = EnvelopeCodec();
    final hello = codec.toJson(const Envelope(Hello(ruleset: ruleset, playerName: 'x', appVersion: '1')))
      ..['p'] = {
        'ruleset': {'id': ruleset.id, 'hash': ruleset.hash, 'engine': ruleset.engineVersion},
        'name': rtlOverride + 'я' * 5000,
        'app': '1',
      };
    final name = (codec.fromJson(hello).message as Hello).playerName;
    expect(utf8.encode(name).length, lessThanOrEqualTo(maxDisplayNameBytes));
    expect(name.startsWith(rtlOverride), isFalse);

    final presence = codec.toJson(const Envelope(OpponentPresence(online: true, name: 'x'), seq: 1))
      ..['p'] = {'online': true, 'name': 'Ци\u0000ри'};
    expect((codec.fromJson(presence).message as OpponentPresence).name, 'Цири');
  });
}
