import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent_engine/gwent_engine.dart' show Row;

void main() {
  const geometry = FieldGeometry(width: 390);

  test('бюджет высоты макета: 48 + 240 + 40 + 240 + 48 + 135 = 751', () {
    expect(FieldGeometry.budgetHeight, 751);
    expect(geometry.height, 751);
    expect(geometry.opponentBar, const Rect.fromLTWH(0, 0, 390, 48));
    expect(geometry.strip, const Rect.fromLTWH(0, 288, 390, 40));
    expect(geometry.myBar, const Rect.fromLTWH(0, 568, 390, 48));
    expect(geometry.hand, const Rect.fromLTWH(0, 616, 390, 135));
  });

  test('на высоком экране лишнее достаётся руке, ряды остаются по 80 pt', () {
    const tall = FieldGeometry(width: 390, handHeight: 200);
    expect(tall.height, 816);
    expect(tall.rowRect(Row.melee, mine: true).height, 80);
    expect(tall.hand.height, 200);
  });

  test('вписывание в область: высокий экран отдаёт лишнее руке, низкий уменьшает холст целиком', () {
    final tall = FieldFit(390, 844);
    expect(tall.scale, 1);
    expect((tall.width, tall.height), (390, 844));
    expect(tall.geometry.handHeight, 844 - (751 - 135));

    final low = FieldFit(390, 600);
    expect(low.scale, closeTo(600 / 751, 1e-9));
    expect(low.height, closeTo(751, 1e-9), reason: 'холст остаётся высотой в бюджет макета');
    expect(low.width, closeTo(390 * 751 / 600, 1e-9));
    expect(low.geometry.handHeight, closeTo(135, 1e-9));
  });

  test('ряды соперника сверху вниз: осадный, дальний, ближний; мои: ближний, дальний, осадный', () {
    expect(geometry.rowRect(Row.siege, mine: false).top, 48);
    expect(geometry.rowRect(Row.melee, mine: false).top, 48 + 160);
    expect(geometry.rowRect(Row.melee, mine: true).top, 328);
    expect(geometry.rowRect(Row.siege, mine: true).top, 328 + 160);
    // Между рядами и полосами нет щелей.
    expect(geometry.rowRect(Row.melee, mine: false).bottom, geometry.strip.top);
    expect(geometry.rowRect(Row.siege, mine: true).bottom, geometry.myBar.top);
  });

  test('слот рога и бейдж силы лежат в колонке слева и не пересекаются', () {
    final score = geometry.scoreRect(Row.ranged, mine: true);
    final horn = geometry.hornSlotRect(Row.ranged, mine: true);
    final cards = geometry.cardsArea(Row.ranged, mine: true);
    expect(score.size, const Size(26, 24));
    expect(horn.size, const Size(31, 44));
    expect(score.overlaps(horn), isFalse);
    expect(horn.right, lessThanOrEqualTo(cards.left));
    expect(geometry.rowRect(Row.ranged, mine: true).contains(horn.bottomRight), isTrue);
  });

  test('зона карт 334 pt, без перекрытия помещается шесть карт', () {
    expect(geometry.cardsArea(Row.melee, mine: true).width, 334);
    expect(geometry.cardsWithoutOverlap, 6);
  });

  test('карты без перекрытия стоят по центру с промежутком 4 pt', () {
    final area = geometry.cardsArea(Row.melee, mine: true);
    final rects = [for (var i = 0; i < 3; i++) geometry.cardRect(Row.melee, i, 3, mine: true)];
    expect(rects[1].left - rects[0].right, 4);
    expect(rects[2].left - rects[1].right, 4);
    expect((rects.first.left - area.left - (area.right - rects.last.right)).abs(), lessThanOrEqualTo(1));
    expect(rects.first.size, const Size(52, 74));
    expect(rects.first.top, geometry.rowRect(Row.melee, mine: true).top + 3);
  });

  test('при переполнении шаг сжимается, первая карта у края зоны, последняя у правого края', () {
    final area = geometry.cardsArea(Row.melee, mine: true);
    final rects = [for (var i = 0; i < 9; i++) geometry.cardRect(Row.melee, i, 9, mine: true)];
    expect(rects.first.left, area.left);
    expect((rects.last.right - area.right).abs(), lessThanOrEqualTo(1));
    final step = rects[1].left - rects[0].left;
    expect(step, lessThan(56));
    for (var i = 1; i < rects.length; i++) {
      expect((rects[i].left - rects[i - 1].left - step).abs(), lessThanOrEqualTo(1));
    }
  });

  test('ряд сжимается до сжатой силы, когда шаг меньше медальона, и только у перекрытых карт', () {
    expect(geometry.cardStep(3), 56);
    expect(geometry.isRowCompact(1), isFalse);
    expect(geometry.isRowCompact(9), isFalse, reason: 'шаг 35 pt: медальон со стрелкой виден');
    expect(geometry.isRowCompact(10), isFalse, reason: 'шаг 31 pt');
    expect(geometry.isRowCompact(11), isTrue, reason: 'шаг 28 pt');
    final step = geometry.cardStep(19);
    expect(step, closeTo((334 - 52) / 18, 0.001));
    expect(geometry.isRowCompact(19), isTrue);
    // Шаг совпадает с положением карт, а последняя карта открыта целиком.
    final first = geometry.cardRect(Row.melee, 0, 19, mine: true);
    final second = geometry.cardRect(Row.melee, 1, 19, mine: true);
    expect((second.left - first.left - step).abs(), lessThanOrEqualTo(1));
  });

  test('одна карта стоит по центру зоны', () {
    final area = geometry.cardsArea(Row.siege, mine: false);
    final rect = geometry.cardRect(Row.siege, 0, 1, mine: false);
    expect((rect.center.dx - area.center.dx).abs(), lessThanOrEqualTo(1));
  });

  group('рука', () {
    test('шаг веера не больше 81 pt и сжимается до полей 28 pt', () {
      expect(geometry.fanStep(1), 0);
      expect(geometry.fanStep(3), 81);
      expect(geometry.fanStep(10), closeTo((390 - 56 - 77) / 9, 1e-9));
    });

    test('на экране 390 pt одиннадцать карт веером, двенадцать прокруткой', () {
      expect(geometry.handScrolls(10), isFalse);
      expect(geometry.handScrolls(11), isFalse);
      expect(geometry.handScrolls(12), isTrue);
    });

    test('на экране 360 pt десять карт веером, одиннадцать прокруткой', () {
      const phone = FieldGeometry(width: 360);
      expect(phone.handScrolls(10), isFalse);
      expect(phone.handScrolls(11), isTrue);
    });

    test('на узком экране веер сменяется прокруткой раньше', () {
      const narrow = FieldGeometry(width: 320);
      expect(narrow.handScrolls(7), isFalse);
      expect(narrow.handScrolls(9), isTrue);
    });

    test('одна карта в руке не прокручивается', () {
      expect(geometry.handScrolls(1), isFalse);
      expect(geometry.handScrolls(0), isFalse);
    });
  });

  group('зоны магнита карт ряда (макет 14, ступень B)', () {
    test('зоны делят ряд по горизонтали без щелей и перекрытий и занимают всю высоту ряда', () {
      for (final count in [1, 3, 8, 12, 19]) {
        final row = geometry.rowRect(Row.ranged, mine: true);
        final zones = geometry.magnetZones(Row.ranged, count, mine: true);
        expect(zones, hasLength(count));
        for (final zone in zones) {
          expect(zone.top, row.top);
          expect(zone.bottom, row.bottom);
        }
        for (var i = 1; i < count; i++) {
          expect(zones[i].left, zones[i - 1].right, reason: 'зоны $i и ${i - 1} при $count картах');
        }
      }
    });

    test('на узком экране 320 pt зоны тоже делят ряд, каждая карта лежит в своей зоне', () {
      const narrow = FieldGeometry(width: 320);
      for (final count in [2, 6, 12, 19]) {
        final zones = narrow.magnetZones(Row.siege, count, mine: true);
        for (var i = 0; i < count; i++) {
          final card = narrow.cardRect(Row.siege, i, count, mine: true);
          expect(zones[i].left, lessThanOrEqualTo(card.left), reason: 'карта $i из $count');
          expect(zones[i].width, greaterThan(0));
          if (i > 0) expect(zones[i].left, zones[i - 1].right);
        }
      }
    });

    test('в плотном ряду зона карты — её видимая полоска: от левого края до левого края следующей', () {
      final zones = geometry.magnetZones(Row.melee, 19, mine: true);
      for (var i = 1; i < 18; i++) {
        final card = geometry.cardRect(Row.melee, i, 19, mine: true);
        final next = geometry.cardRect(Row.melee, i + 1, 19, mine: true);
        expect(zones[i].left, card.left);
        expect(zones[i].right, next.left);
      }
    });

    test('в свободном ряду щель между картами делится пополам, карта покрыта целиком', () {
      final zones = geometry.magnetZones(Row.melee, 3, mine: true);
      final rects = [for (var i = 0; i < 3; i++) geometry.cardRect(Row.melee, i, 3, mine: true)];
      for (var i = 0; i < 3; i++) {
        expect(zones[i].left, lessThanOrEqualTo(rects[i].left));
        expect(zones[i].right, greaterThanOrEqualTo(rects[i].right));
      }
      final gap = rects[1].left - rects[0].right;
      expect(zones[0].right, rects[0].right + gap / 2);
    });

    test('у краёв ряда зона тянется за карту на дальность магнита и не выходит за зону карт', () {
      final rect = geometry.rowRect(Row.melee, mine: true);
      final area = geometry.cardsArea(Row.melee, mine: true);
      final one = geometry.magnetZones(Row.melee, 1, mine: true).single;
      final card = geometry.cardRect(Row.melee, 0, 1, mine: true);
      expect(one.left, card.left - FieldGeometry.magnetReach);
      expect(one.right, card.right + FieldGeometry.magnetReach);
      final full = geometry.magnetZones(Row.melee, 19, mine: true);
      expect(full.first.left, area.left);
      expect(full.last.right, lessThanOrEqualTo(rect.right));
    });

    test('пустой ряд зон не даёт', () {
      expect(geometry.magnetZones(Row.siege, 0, mine: true), isEmpty);
    });
  });
}
