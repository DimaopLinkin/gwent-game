import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/card_face.dart';
import 'package:gwent/src/core/presentation/components/card_pile.dart';
import 'package:gwent/src/core/presentation/components/pass_button.dart';
import 'package:gwent/src/core/presentation/components/player_bar.dart';
import 'package:gwent/src/core/presentation/components/row_score_pill.dart';
import 'package:gwent/src/core/presentation/components/weather_strip.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

/// Компактные компоненты поля: пилюля силы ряда, стопка карт, полоса игрока, центральная полоса, «Пас» 70×38.
void main() {
  setUpAll(loadDesignFonts);

  const leader = LeaderCardFace(
    art: null,
    name: 'Эредин',
    faction: GwentFaction.monsters,
  );

  Future<void> pump(WidgetTester tester, Widget child, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(Align(alignment: Alignment.topLeft, child: child)));
  }

  group('RowScorePill', () {
    testWidgets('пилюля 26×24 по цифре: одна и две цифры не растягивают её', (tester) async {
      await pump(tester, const RowScorePill(score: 7));
      expect(tester.getSize(find.byType(RowScorePill)), const Size(26, 24));
      await pump(tester, const RowScorePill(score: 42));
      expect(tester.getSize(find.byType(RowScorePill)), const Size(26, 24));
      await pump(tester, const RowScorePill(score: 128));
      expect(tester.getSize(find.byType(RowScorePill)).width, greaterThanOrEqualTo(26));
      expect(tester.getSize(find.byType(RowScorePill)).height, 24);
    });

    testWidgets('читается скринридером как сила ряда', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const RowScorePill(score: 7));
      expect(find.bySemanticsLabel('Сила ряда 7'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('кольцо цвета изменения: усилен, ослаблен, без изменений', (tester) async {
      Color ring(WidgetTester tester) {
        final box = tester.widget<Container>(
          find.descendant(of: find.byType(RowScorePill), matching: find.byType(Container)).first,
        );
        return (box.decoration! as BoxDecoration).boxShadow!.single.color;
      }

      await pump(tester, const RowScorePill(score: 7));
      final neutral = ring(tester);
      await pump(tester, const RowScorePill(score: 7, tone: RowScoreTone.boosted));
      final boosted = ring(tester);
      await pump(tester, const RowScorePill(score: 7, tone: RowScoreTone.weakened));
      final weakened = ring(tester);
      expect({neutral, boosted, weakened}, hasLength(3));
    });
  });

  group('CardPile', () {
    testWidgets('колода: рубашка и число, сброс без карт: пустой слот', (tester) async {
      await pump(tester, const CardPile(top: CardBackFace(faction: GwentFaction.monsters), count: 57));
      expect(tester.getSize(find.byType(CardPile)), const Size(31, 44));
      expect(find.text('57'), findsOneWidget);
      await pump(tester, const CardPile(top: null, count: 0));
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('тап по стопке вызывает колбэк; у колоды без колбэка нажатие игнорируется', (tester) async {
      var taps = 0;
      await pump(tester, CardPile(top: null, count: 3, semanticsLabel: 'Сброс: 3 карты', onTap: () => taps++));
      await tester.tap(find.byType(CardPile));
      expect(taps, 1);
      await pump(tester, const CardPile(top: null, count: 3));
      await tester.tap(find.byType(CardPile));
      expect(taps, 1);
    });
  });

  group('PlayerBar', () {
    PlayerBar bar({
      bool mine = true,
      bool leading = false,
      bool leaderAvailable = false,
      Widget? trailing,
      Widget? status,
      PlayerBarAnchors? anchors,
      VoidCallback? onLeaderTap,
      VoidCallback? onDiscardTap,
    }) => PlayerBar(
      name: 'Соперник',
      faction: GwentFaction.monsters,
      leader: leader,
      lifeRemaining: 1,
      handCount: 9,
      score: 15,
      deckCount: 57,
      discardCount: 4,
      mine: mine,
      leading: leading,
      leaderAvailable: leaderAvailable,
      trailing: trailing,
      status: status,
      anchors: anchors,
      onLeaderTap: onLeaderTap,
      onDiscardTap: onDiscardTap,
    );

    testWidgets('высота 48 pt, имя, счёт, карты в руке, колода и сброс', (tester) async {
      await pump(tester, bar());
      expect(tester.getSize(find.byType(PlayerBar)).height, 48);
      expect(find.text('Соперник'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('57'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('помещается на самом узком экране 320 pt вместе с кнопкой паса', (tester) async {
      await pump(tester, bar(trailing: PassButton(onPressed: () {}, compact: true)), width: 320);
      expect(tester.takeException(), isNull);
    });

    group('индикатор связи', () {
      const statusKey = Key('status');

      /// Индикатор того же размера, что самая широкая метка: «Нестабильно» со значком.
      Widget status() => const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(key: statusKey, width: 80, height: 18),
      );

      Rect rectOf(GlobalKey key) {
        final box = key.currentContext!.findRenderObject()! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }

      for (final width in [360.0, 390.0]) {
        testWidgets('ширина $width pt: не налезает на счёт, колоду, сброс и имя', (tester) async {
          final anchors = PlayerBarAnchors();
          await pump(
            tester,
            bar(mine: false, status: status(), anchors: anchors),
            width: width,
          );

          final indicator = tester.getRect(find.byKey(statusKey));
          for (final anchor in [anchors.score, anchors.deck, anchors.discard, anchors.leader]) {
            expect(indicator.overlaps(rectOf(anchor)), isFalse);
          }
          expect(indicator.overlaps(tester.getRect(find.text('Соперник'))), isFalse);
          expect(indicator.overlaps(tester.getRect(find.text('9'))), isFalse);
          expect(tester.getRect(find.byType(PlayerBar)).contains(indicator.center), isTrue);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('с меткой «Спасовал» и на экране 320 pt полоса не ломается', (tester) async {
        await pump(
          tester,
          bar(mine: false, status: status(), trailing: const SizedBox(width: 60, height: 20)),
          width: 360,
        );
        expect(tester.takeException(), isNull);
        await pump(tester, bar(mine: false, status: status()), width: 320);
        expect(tester.takeException(), isNull);
        await pump(
          tester,
          bar(mine: false, status: const SizedBox.shrink(), trailing: const SizedBox(width: 60, height: 20)),
          width: 320,
        );
        // Свёрнутый индикатор не отнимает у второй строки даже зазор: переполнения не прибавилось.
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('корона только у ведущего', (tester) async {
      Finder crown() =>
          find.byWidgetPredicate((widget) => widget is GwentIconView && widget.icon == GwentIcon.iconCrownLeading);
      await pump(tester, bar());
      expect(crown(), findsNothing);
      await pump(tester, bar(leading: true));
      expect(crown(), findsOneWidget);
    });

    testWidgets('тап по лидеру и по сбросу доходит до колбэков', (tester) async {
      var leaderTaps = 0;
      var discardTaps = 0;
      await pump(tester, bar(onLeaderTap: () => leaderTaps++, onDiscardTap: () => discardTaps++));
      await tester.tapAt(const Offset(22, 24));
      await tester.tap(find.byType(CardPile).last);
      expect((leaderTaps, discardTaps), (1, 1));
    });

    testWidgets('справа метка или кнопка', (tester) async {
      await pump(tester, bar(trailing: const Text('Спасовал')));
      expect(find.text('Спасовал'), findsOneWidget);
    });
  });

  group('WeatherStrip', () {
    const slots = [
      (rowIcon: GwentIcon.rowMelee, weather: GwentWeather.frost),
      (rowIcon: GwentIcon.rowRanged, weather: null),
      (rowIcon: GwentIcon.rowSiege, weather: null),
    ];

    testWidgets('высота 40 pt: слоты, статус и раунд', (tester) async {
      await pump(tester, WeatherStrip(slots: slots, status: 'Ваш ход', round: 2));
      expect(tester.getSize(find.byType(WeatherStrip)).height, 40);
      expect(find.text('Ваш ход'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('цель хода: тап вызывает колбэк', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        WeatherStrip(slots: slots, status: 'Коснитесь полосы', round: 1, isTarget: true, onTap: () => taps++),
      );
      await tester.tap(find.byType(WeatherStrip));
      expect(taps, 1);
    });

    testWidgets('на узком экране длинный статус обрезается многоточием без переполнения', (tester) async {
      await pump(
        tester,
        WeatherStrip(slots: slots, status: 'Соперник выбирает, кто ходит первым в раунде', round: 3),
        width: 320,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('место под кнопку паузы сдвигает метку раунда влево на ширину круга', (tester) async {
      await pump(tester, WeatherStrip(slots: slots, status: 'Ваш ход', round: 2));
      final plain = tester.getTopRight(find.textContaining('2').last).dx;
      await pump(tester, WeatherStrip(slots: slots, status: 'Ваш ход', round: 2, showPauseSlot: true));
      final shifted = tester.getTopRight(find.textContaining('2').last).dx;
      expect(plain - shifted, WeatherStrip.pauseSlotWidth);
      expect(tester.getSize(find.byType(WeatherStrip)).height, 40);
    });
  });

  group('PassButton compact', () {
    testWidgets('кнопка 70×38 pt с зоной нажатия 44 pt', (tester) async {
      await pump(tester, PassButton(onPressed: () {}, compact: true));
      final area = tester.getSize(find.byType(PassButton));
      expect(area.height, 44);
      expect(area.width, PassButton.compactWidth);
      final surface = find.descendant(of: find.byType(PassButton), matching: find.byType(DecoratedBox)).first;
      expect(tester.getSize(surface), const Size(70, 38));
    });

    testWidgets('нажатие за пределами 38 pt, но внутри 44 pt срабатывает', (tester) async {
      var passes = 0;
      await pump(tester, PassButton(onPressed: () => passes++, compact: true));
      final rect = tester.getRect(find.byType(PassButton));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
      expect(passes, 1);
    });

    testWidgets('обычная кнопка остаётся 56 pt', (tester) async {
      await pump(tester, PassButton(onPressed: () {}));
      expect(tester.getSize(find.byType(PassButton)).height, PassButton.height);
    });
  });
}
