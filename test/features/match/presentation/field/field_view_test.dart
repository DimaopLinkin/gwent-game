import 'package:flutter/material.dart' hide Intent, Row;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/core/presentation/card/card_detail_view.dart';
import 'package:gwent/src/core/presentation/card/card_highlight.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/card/parts/compact_power.dart';
import 'package:gwent/src/core/presentation/card/parts/power_medallion.dart';
import 'package:gwent/src/core/presentation/components/card_pile.dart';
import 'package:gwent/src/core/presentation/components/pass_button.dart';
import 'package:gwent/src/core/presentation/components/pause_button.dart';
import 'package:gwent/src/core/presentation/components/row_score_pill.dart';
import 'package:gwent/src/core/presentation/components/weather_strip.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_weather.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/haptics/application/play_haptic.dart';
import 'package:gwent/src/features/haptics/domain/haptic_pattern.dart';
import 'package:gwent/src/features/match/presentation/field/banner_layer.dart';
import 'package:gwent/src/features/match/presentation/field/drag_feedback.dart';
import 'package:gwent/src/features/match/presentation/field/field_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent/src/features/match/presentation/field/field_sheets.dart';
import 'package:gwent/src/features/match/presentation/field/field_state.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/field/hand_view.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/overlays/pause_layers.dart';
import 'package:gwent/src/features/match/presentation/overlays/round_summary_view.dart';
import 'package:gwent/src/features/match/presentation/overlays/rules_view.dart';
import 'package:gwent/src/features/settings/application/watch_settings.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/fakes.dart';
import '../../../../support/fonts.dart';
import '../../../../support/localized_app.dart';
import '../../../../support/match_fixtures.dart';
import 'field_fixtures.dart';

/// Поле в тесте: проекция меняется через [view], ходы копятся в [intents].
final class _Harness {
  _Harness(PlayerView initial) : view = ValueNotifier(initial) {
    haptic = PlayHaptic(haptics, WatchSettings(InMemorySettingsRepository()));
    cubit = FieldCubit(haptic: haptic);
  }

  final ValueNotifier<PlayerView> view;
  final RecordingHapticOutput haptics = RecordingHapticOutput();
  late final PlayHaptic haptic;
  late final FieldCubit cubit;
  final List<Intent> intents = [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;

  setUpAll(() async {
    content = await loadBaseContent();
    await loadDesignFonts();
  });
  setUp(() => cards = TestCards(content));

  // Размер экрана 390×844 даёт руке 228 pt вместо 135.
  const geometry = FieldGeometry(width: 390, handHeight: 844 - 616);

  Future<_Harness> pumpField(
    WidgetTester tester,
    PlayerView view, {
    bool confirmPass = false,
    bool hints = true,
    bool hotSeat = false,
    bool readOnly = false,
    VoidCallback? onSettings,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = _Harness(view);
    addTearDown(harness.cubit.close);
    addTearDown(harness.haptic.dispose);
    await tester.pumpWidget(
      localizedApp(
        BlocProvider.value(
          value: harness.cubit,
          child: ValueListenableBuilder(
            valueListenable: harness.view,
            builder: (context, view, _) => FieldView(
              view: view,
              content: content,
              roster: rosterOf(cards, hotSeat: hotSeat),
              onIntent: harness.intents.add,
              confirmPass: confirmPass,
              hints: hints,
              readOnly: readOnly,
              onSettings: onSettings,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return harness;
  }

  Finder handCards() => find.descendant(of: find.byType(HandView), matching: find.byType(GwentCard));

  Future<void> tapField(WidgetTester tester, Offset position) async {
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 250));
  }

  Offset emptyPart(Row row, {required bool mine}) {
    final area = geometry.cardsArea(row, mine: mine);
    return Offset(area.right - 12, area.center.dy);
  }

  /// Состояние партии доходит до держателя поля так же, как с экрана партии: с событиями, которых игрок не видел.
  void feed(_Harness harness, PlayerView view, List<GameEvent> events, {bool hotSeat = false}) =>
      harness.cubit.onMatchState(
        MatchInProgress(
          view: view,
          content: content,
          roster: rosterOf(cards, hotSeat: hotSeat),
          events: events,
        ),
      );

  String bannerTitle(WidgetTester tester) => tester.widget<MatchBannerStrip>(find.byType(MatchBannerStrip)).title;

  Future<void> endBanners(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('тесный ряд', () {
    /// Ряд из [count] карт: по кругу базовая, усиленная, ещё сильнее, ослабленная и герой.
    RowView crowded(int count) {
      final views = <FieldCardView>[];
      for (var i = 0; i < count; i++) {
        final card = i % 5 == 4 ? cards.hero() : cards.unit(Row.melee);
        final base = cards.strength(card);
        views.add(FieldCardView(card: card, strength: base + const [0, 1, 3, -1, 0][i % 5]));
      }
      return RowView(cards: views, slot: null, weather: false, strength: views.fold(0, (sum, v) => sum + v.strength));
    }

    for (final size in const [Size(393, 852), Size(360, 780)]) {
      testWidgets('19 карт на экране ${size.width.toInt()} pt: сила и стрелка каждой карты в видимой полоске', (
        tester,
      ) async {
        final row = crowded(19);
        await pumpField(
          tester,
          viewOf(cards, me: sideOf(cards, Seat.one, rows: {Row.melee: row})),
          size: size,
        );
        expect(tester.takeException(), isNull);
        final field = FieldGeometry(width: size.width);
        final compact = find.byType(CompactPower);
        expect(compact, findsNWidgets(18), reason: 'последняя карта открыта целиком');
        final step = field.cardStep(19);
        final pills = tester.widgetList<CompactPower>(compact).toList();
        final rects = [for (final element in compact.evaluate()) tester.getRect(find.byWidget(element.widget))];
        for (var i = 0; i < pills.length; i++) {
          final view = row.cards[i];
          final base = cards.strength(view.card);
          // Таблетка внутри видимой полоски карты: следующая карта её не закрывает.
          expect(rects[i].width, closeTo(step - 1, 0.5));
          if (i > 0) expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
          expect(pills[i].power, view.strength, reason: 'карта $i');
          expect(
            pills[i].look,
            i % 5 == 4
                ? PowerLook.hero
                : view.strength > base
                ? PowerLook.buffed
                : view.strength < base
                ? PowerLook.debuffed
                : PowerLook.base,
            reason: 'карта $i',
          );
        }
        // Стрелки усиления и ослабления есть у каждой сжатой карты, которая изменилась.
        int arrows(GwentIcon icon) => find
            .descendant(of: compact, matching: find.byWidgetPredicate((w) => w is GwentIconView && w.icon == icon))
            .evaluate()
            .length;
        expect(arrows(GwentIcon.iconPowerUp), pills.where((p) => p.look == PowerLook.buffed).length);
        expect(arrows(GwentIcon.iconPowerDown), pills.where((p) => p.look == PowerLook.debuffed).length);
        expect(arrows(GwentIcon.iconPowerDown), greaterThan(0));
      });
    }

    testWidgets('в ряду из шести карт медальоны остаются полными', (tester) async {
      await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, rows: {Row.melee: crowded(6)})));
      expect(find.byType(CompactPower), findsNothing);
    });
  });

  group('розыгрыш из руки', () {
    testWidgets('отряд: тап по карте выбирает её, тап по подсвеченному ряду играет в него', (tester) async {
      final unit = cards.unit(Row.melee);
      final harness = await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])),
      );
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.selected, unit.id);
      await tester.pump();
      expect(find.text('Выберите ряд'), findsOneWidget, reason: 'подсказка в центральной полосе вместо статуса');
      expect(find.text('Отмена'), findsNothing, reason: 'отмена теперь повторным тапом, кнопки нет');

      await tapField(tester, emptyPart(Row.melee, mine: true));
      expect(harness.intents, [PlayCard(unit.id, row: Row.melee)]);
      expect(harness.cubit.state.selected, isNull);
      await endBanners(tester);
    });

    testWidgets('тап по ряду, который не цель, снимает выбор', (tester) async {
      final unit = cards.unit(Row.melee);
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      await tapField(tester, emptyPart(Row.ranged, mine: true));
      expect(harness.intents, isEmpty, reason: 'дальний ряд не цель этого отряда');
      expect(harness.cubit.state.selected, isNull);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Выберите ряд'), findsNothing, reason: 'подсказка ушла');
      await endBanners(tester);
    });

    testWidgets('повторный тап по выбранной карте снимает выбор', (tester) async {
      final harness = await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)])),
      );
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.selected, isNull);
      await endBanners(tester);
    });

    testWidgets('подсказки выключены: в полосе остаётся статус хода', (tester) async {
      final harness = await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)])),
        hints: false,
      );
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.selected, isNotNull);
      expect(find.text('Выберите ряд'), findsNothing);
      await endBanners(tester);
      expect(find.text('Ваш ход'), findsOneWidget);
    });

    testWidgets('проворный отряд: два ряда на выбор', (tester) async {
      final agile = cards.agile();
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [agile])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Ближний или дальний ряд'), findsOneWidget);
      await tapField(tester, emptyPart(Row.ranged, mine: true));
      expect(harness.intents, [PlayCard(agile.id, row: Row.ranged)]);
      await endBanners(tester);
    });

    testWidgets('шпион: подсвечен ряд соперника, туда он и уходит', (tester) async {
      final spy = cards.spy();
      final row = (cards.definition(spy) as UnitCardDefinition).placement.rows.single;
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [spy])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Выберите ряд соперника'), findsOneWidget);
      await tapField(tester, emptyPart(row, mine: true));
      expect(harness.intents, isEmpty, reason: 'свой ряд шпиону не подходит');
      expect(harness.cubit.state.selected, isNull, reason: 'тап не по цели снял выбор');
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      await tapField(tester, emptyPart(row, mine: false));
      expect(harness.intents, [PlayCard(spy.id, row: row)]);
      await endBanners(tester);
    });

    testWidgets('погода играется тапом по центральной полосе', (tester) async {
      final weather = cards.special<WeatherAbility>();
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [weather])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Бросьте на поле'), findsOneWidget);
      expect(tester.widget<WeatherStrip>(find.byType(WeatherStrip)).isTarget, isTrue);
      await tapField(tester, geometry.strip.center);
      expect(harness.intents, [PlayCard(weather.id)]);
      await endBanners(tester);
    });

    testWidgets('рог кладётся в свободный слот: тап по ряду', (tester) async {
      final horn = cards.special<HornCardAbility>();
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [horn])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Выберите ряд для рога'), findsOneWidget);
      await tapField(tester, emptyPart(Row.siege, mine: true));
      expect(harness.intents, [PlayCard(horn.id, row: Row.siege)]);
      await endBanners(tester);
    });

    testWidgets('Чучело: тап по своему отряду на поле', (tester) async {
      final decoy = cards.special<DecoyAbility>();
      final unit = cards.unit(Row.ranged);
      final harness = await pumpField(
        tester,
        viewOf(
          cards,
          me: sideOf(
            cards,
            Seat.one,
            hand: [decoy],
            rows: {
              Row.ranged: rowOf([unit], cards),
            },
          ),
        ),
      );
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Выберите отряд'), findsOneWidget);
      final fieldCard = find.descendant(
        of: find.byType(Stack),
        matching: find.byWidgetPredicate((widget) => widget is GwentCard && widget.size.name == 'row'),
      );
      await tester.tap(fieldCard.first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, [PlayCard(decoy.id, target: unit.id)]);
      await endBanners(tester);
    });

    testWidgets('перетаскивание карты на ряд играет её', (tester) async {
      final unit = cards.unit(Row.siege);
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.cubit.state.selected, unit.id, reason: 'начатое перетаскивание выбирает карту');
      await gesture.moveTo(emptyPart(Row.siege, mine: true));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, [PlayCard(unit.id, row: Row.siege)]);
      expect(harness.haptics.played, [HapticPattern.soft, HapticPattern.medium], reason: 'вход в цель и отпускание');
      await endBanners(tester);
    });

    testWidgets('бросок мимо цели ничего не играет', (tester) async {
      final unit = cards.unit(Row.siege);
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -60));
      await gesture.moveTo(emptyPart(Row.melee, mine: true));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, isEmpty);
      expect(harness.haptics.played, [HapticPattern.double], reason: 'мимо цели две короткие вибрации');
      expect(harness.cubit.state.selected, isNull, reason: 'выбор поставило перетаскивание: карта вернулась в руку');
      await endBanners(tester);
    });

    testWidgets('цель под пальцем горит ярко, мини-карта тускнеет вне цели; вход и выход дают вибрацию', (
      tester,
    ) async {
      final unit = cards.unit(Row.siege);
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 200));
      double feedbackOpacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(of: find.byType(DragFeedback), matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      expect(feedbackOpacity(), DragFeedback.dimmedOpacity);

      await gesture.moveTo(emptyPart(Row.siege, mine: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(feedbackOpacity(), 1);
      expect(harness.haptics.played, [HapticPattern.soft]);

      await gesture.moveTo(emptyPart(Row.melee, mine: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(feedbackOpacity(), DragFeedback.dimmedOpacity);
      expect(harness.haptics.played, [HapticPattern.soft, HapticPattern.tick]);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.haptics.played.last, HapticPattern.double);
      await endBanners(tester);
    });

    testWidgets('погода: тап по ряду не играет карту, а снимает выбор, играет только тап по полосе', (tester) async {
      final weather = cards.special<WeatherAbility>();
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [weather])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      await tapField(tester, emptyPart(Row.melee, mine: false));
      expect(harness.intents, isEmpty, reason: 'случайный тап по полю не разыгрывает необратимую карту');
      expect(harness.cubit.state.selected, isNull);

      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      await tapField(tester, geometry.strip.center);
      expect(harness.intents, [PlayCard(weather.id)]);
      await endBanners(tester);
    });

    testWidgets('бросок мимо после тапа по карте оставляет её выбранной', (tester) async {
      final unit = cards.unit(Row.siege);
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -60));
      await gesture.moveTo(emptyPart(Row.melee, mine: true));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.selected, unit.id);
      await endBanners(tester);
    });

    testWidgets('пока поле занято баннером, тащить карту нельзя: ни входа, ни отпускания, ни «мимо»', (tester) async {
      final unit = cards.unit(Row.siege);
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      feed(harness, harness.view.value, const [RoundStarted(1, Seat.one)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.cubit.state.isBusy, isTrue);
      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(emptyPart(Row.siege, mine: true));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, isEmpty);
      expect(harness.haptics.played, isEmpty);
      await endBanners(tester);
    });

    testWidgets('погода: бросок на ряд соперника играет карту', (tester) async {
      final weather = cards.special<WeatherAbility>();
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [weather])));
      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(emptyPart(Row.ranged, mine: false));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, [PlayCard(weather.id)]);
      await endBanners(tester);
    });

    testWidgets('Чучело: бросок на свой отряд играет карту', (tester) async {
      final decoy = cards.special<DecoyAbility>();
      final unit = cards.unit(Row.ranged);
      final harness = await pumpField(
        tester,
        viewOf(
          cards,
          me: sideOf(
            cards,
            Seat.one,
            hand: [decoy],
            rows: {
              Row.ranged: rowOf([unit], cards),
            },
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 50));
      final target = find.byWidgetPredicate((widget) => widget is GwentCard && widget.size.name == 'row').first;
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, [PlayCard(decoy.id, target: unit.id)]);
      await endBanners(tester);
    });
  });

  group('только просмотр (реплей)', () {
    testWidgets('тап по карте руки и по ряду ничего не играет, пас недоступен, паузы нет', (tester) async {
      final unit = cards.unit(Row.melee);
      final harness = await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])),
        readOnly: true,
      );
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.selected, isNull);

      await tapField(tester, emptyPart(Row.melee, mine: true));
      expect(harness.intents, isEmpty);
      expect(tester.widget<PassButton>(find.byType(PassButton)).enabled, isFalse);
      expect(find.byType(PauseButton), findsNothing);
    });
  });

  group('нельзя сыграть', () {
    testWidgets('карта без допустимого хода: тост, выбор не ставится', (tester) async {
      final harness = await pumpField(
        tester,
        viewOf(
          cards,
          me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)], playable: const {}),
        ),
      );
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Эту карту сейчас некуда сыграть'), findsOneWidget);
      expect(harness.cubit.state.selected, isNull);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Эту карту сейчас некуда сыграть'), findsNothing, reason: 'тост уходит через 3 с');
    });

    testWidgets('ход соперника: тост и статус на полосе', (tester) async {
      await pumpField(
        tester,
        viewOf(
          cards,
          turn: Seat.two,
          me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)], playable: const {}),
        ),
      );
      expect(find.text('Ход соперника'), findsOneWidget);
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Сейчас ходит соперник'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('после своего паса: тост и статус «Вы спасовали»', (tester) async {
      await pumpField(
        tester,
        viewOf(
          cards,
          turn: Seat.two,
          me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)], passed: true, playable: const {}),
        ),
      );
      expect(find.text('Вы спасовали'), findsOneWidget);
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Вы уже спасовали в этом раунде'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('соперник спасовал: метка на его полосе', (tester) async {
      await pumpField(tester, viewOf(cards, opponent: sideOf(cards, Seat.two, passed: true)));
      expect(find.text('Спасовал'), findsOneWidget);
      await endBanners(tester);
    });
  });

  group('выбор, которого ждёт движок', () {
    testWidgets('ряд для отряда: подсказка без отмены, тап по ряду отвечает движку', (tester) async {
      final subject = cards.agile();
      final harness = await pumpField(
        tester,
        viewOf(
          cards,
          me: sideOf(cards, Seat.one, playable: const {}),
          choice: PendingChoice(
            seat: Seat.one,
            kind: ChoiceKind.unitRow,
            options: const [RowOption(Row.melee), RowOption(Row.ranged)],
            subject: subject,
          ),
        ),
      );
      expect(find.text('Выберите ряд для отряда'), findsOneWidget);
      expect(find.text('Ваш выбор'), findsNothing, reason: 'подсказка заменяет статус');
      await tapField(tester, emptyPart(Row.melee, mine: false));
      expect(harness.intents, isEmpty);
      await tapField(tester, emptyPart(Row.ranged, mine: true));
      expect(harness.intents, [const ChooseOption(RowOption(Row.ranged))]);
      await endBanners(tester);
    });

    testWidgets('пока движок ждёт выбора ряда, листы сброса и лидера не открываются и не остаются после', (
      tester,
    ) async {
      final subject = cards.agile();
      final choice = PendingChoice(
        seat: Seat.one,
        kind: ChoiceKind.unitRow,
        options: const [RowOption(Row.melee), RowOption(Row.ranged)],
        subject: subject,
      );
      final harness = await pumpField(
        tester,
        viewOf(
          cards,
          me: sideOf(cards, Seat.one, playable: const {}),
          choice: choice,
        ),
      );
      await tester.tapAt(const Offset(22, 568 + 24));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byType(CardPile).at(1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.overlay, isA<NoOverlay>());
      harness.view.value = viewOf(cards, turn: Seat.two);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(LeaderSheet), findsNothing);
      expect(find.byType(CardGridSheet), findsNothing);
      await endBanners(tester);
    });

    testWidgets('цель медика: лист с картами сброса, закрыть нельзя', (tester) async {
      final fallen = [cards.unit(Row.melee), cards.unit(Row.ranged)];
      final harness = await pumpField(
        tester,
        viewOf(
          cards,
          me: sideOf(cards, Seat.one, discard: fallen, playable: const {}),
          choice: PendingChoice(
            seat: Seat.one,
            kind: ChoiceKind.medicTarget,
            options: [for (final card in fallen) CardOption(card)],
          ),
        ),
      );
      expect(find.text('Медик: вернуть отряд'), findsOneWidget);
      expect(find.text('Отменить выбор нельзя: способность уже сработала'), findsOneWidget);
      final sheetCards = find.descendant(of: find.byType(CardGridSheet), matching: find.byType(GwentCard));
      expect(sheetCards, findsNWidgets(2));
      await tester.tapAt(const Offset(195, 40));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CardGridSheet), findsOneWidget, reason: 'тап по затемнению лист не закрывает');
      await tester.tap(sheetCards.last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, [ChooseOption(CardOption(fallen.last))]);
      await endBanners(tester);
    });

    testWidgets('остальные выборы с картами показывают свои заголовки', (tester) async {
      final options = [cards.unit(Row.melee)];
      for (final (kind, title) in [
        (ChoiceKind.opponentDiscardCard, 'Взять из сброса соперника'),
        (ChoiceKind.ownDiscardCard, 'Взять из своего сброса'),
        (ChoiceKind.handCardToDiscard, 'Сбросьте карту из руки'),
        (ChoiceKind.deckCard, 'Выберите карту из колоды'),
        (ChoiceKind.deckWeather, 'Выберите погоду из колоды'),
      ]) {
        await pumpField(
          tester,
          viewOf(
            cards,
            me: sideOf(cards, Seat.one, playable: const {}),
            choice: PendingChoice(seat: Seat.one, kind: kind, options: [for (final card in options) CardOption(card)]),
          ),
        );
        expect(find.text(title), findsOneWidget, reason: '$kind');
        await endBanners(tester);
      }
    });

    testWidgets('соперник выбирает: статус на полосе, руки заблокированы', (tester) async {
      await pumpField(
        tester,
        viewOf(cards, turn: Seat.two, opponentChoosing: ChoiceKind.medicTarget),
      );
      expect(find.text('Соперник выбирает'), findsOneWidget);
    });
  });

  group('листы на малых экранах', () {
    for (final size in const [Size(360, 600), Size(320, 568)]) {
      testWidgets(
        'лист выбора с девятью картами: панель в пределах экрана ${size.width.toInt()}×${size.height.toInt()}, сетка прокручивается',
        (tester) async {
          final fallen = [for (var i = 0; i < 9; i++) cards.unit(Row.values[i % 3])];
          await pumpField(
            tester,
            viewOf(
              cards,
              me: sideOf(cards, Seat.one, discard: fallen, playable: const {}),
              choice: PendingChoice(
                seat: Seat.one,
                kind: ChoiceKind.medicTarget,
                options: [for (final card in fallen) CardOption(card)],
              ),
            ),
            size: size,
          );
          expect(tester.takeException(), isNull);
          final scroll = find.descendant(of: find.byType(CardGridSheet), matching: find.byType(Scrollable)).first;
          final rect = tester.getRect(scroll);
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.top, greaterThanOrEqualTo(size.height * (1 - 0.62) - 1), reason: 'не выше 62 % поля');
          expect(rect.width, lessThanOrEqualTo(size.width));
          expect(tester.state<ScrollableState>(scroll).position.maxScrollExtent, greaterThan(0));
          await endBanners(tester);
        },
      );

      testWidgets('лист лидера на экране ${size.width.toInt()}×${size.height.toInt()} не выходит за экран', (
        tester,
      ) async {
        await pumpField(tester, viewOf(cards), size: size);
        await tester.tapAt(Offset(22, size.height * 0.7));
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
        await endBanners(tester);
      });
    }
  });

  group('листы', () {
    List<String> gridNames(WidgetTester tester) => [
      for (final element
          in find.descendant(of: find.byType(CardGridSheet), matching: find.byType(GwentCard)).evaluate())
        (element.widget as GwentCard).face.name,
    ];

    testWidgets('сброс: сортировка по силе и по порядку, закрытие кнопкой', (tester) async {
      // Порядок сброса: сначала слабая, потом сильная.
      final weak = cards.unit(Row.melee);
      final strong = cards.hero();
      final special = cards.special<HornCardAbility>();
      final harness = await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, discard: [weak, strong, special])),
      );
      await tester.tap(find.byType(CardPile).at(3));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Мой сброс'), findsOneWidget);
      final byStrength = gridNames(tester);
      expect(byStrength.length, 3);
      expect(byStrength.last, isNot(byStrength.first));

      await tester.tap(find.text('По порядку'));
      await tester.pump(const Duration(milliseconds: 250));
      final byOrder = gridNames(tester);
      expect(harness.cubit.state.sort.name, 'byOrder');
      final fieldContent = FieldContent(content: content, l10n: lookupAppLocalizations(const Locale('ru')));
      final names = {
        for (final card in [weak, strong, special]) card.id: fieldContent.face(card).name,
      };
      expect(byOrder, [names[special.id], names[strong.id], names[weak.id]], reason: 'сверху последняя сброшенная');

      await tester.tap(find.text('По силе'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(gridNames(tester).last, names[special.id], reason: 'особые карты в конце');

      await tester.tap(find.text('Закрыть'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CardGridSheet), findsNothing);
      await endBanners(tester);
    });

    testWidgets('сброс соперника и пустой сброс', (tester) async {
      await pumpField(tester, viewOf(cards));
      await tester.tap(find.byType(CardPile).at(1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Сброс соперника'), findsOneWidget);
      expect(find.text('Сброс пуст'), findsOneWidget);
      await tester.tapAt(const Offset(195, 40));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CardGridSheet), findsNothing, reason: 'тап по затемнению закрывает лист сброса');
      await endBanners(tester);
    });

    testWidgets('лидер: «Использовать» отправляет способность и закрывает лист', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      await tester.tapAt(const Offset(22, 568 + 24));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(LeaderSheet), findsOneWidget);
      await tester.tap(find.text('Использовать'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, [const UseLeader()]);
      expect(find.byType(LeaderSheet), findsNothing);
      await endBanners(tester);
    });

    testWidgets('лидер использован: кнопка недоступна, есть пояснение', (tester) async {
      final harness = await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, leaderAvailable: false, leaderUsed: true)),
      );
      await tester.tapAt(const Offset(22, 568 + 24));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Способность уже использована'), findsOneWidget);
      await tester.tap(find.text('Использовать'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, isEmpty);
      await tester.tap(find.text('Закрыть'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(LeaderSheet), findsNothing);
      await endBanners(tester);
    });

    testWidgets('лидер соперника: только просмотр', (tester) async {
      await pumpField(tester, viewOf(cards));
      await tester.tapAt(const Offset(22, 24));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(LeaderSheet), findsOneWidget);
      expect(find.text('Использовать'), findsNothing);
      await endBanners(tester);
    });

    testWidgets('лидер вне своего хода: пояснение, кнопка недоступна', (tester) async {
      final harness = await pumpField(tester, viewOf(cards, turn: Seat.two));
      await tester.tapAt(const Offset(22, 568 + 24));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Её можно применить в свой ход'), findsOneWidget);
      await tester.tap(find.text('Использовать'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, isEmpty);
    });

    testWidgets('пассивный лидер: «Действует постоянно», кнопки «Использовать» нет', (tester) async {
      await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, leader: cards.passiveLeader, leaderAvailable: false)),
      );
      await tester.tapAt(const Offset(22, 568 + 24));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(LeaderSheet), findsOneWidget);
      expect(find.text('Действует постоянно'), findsOneWidget);
      expect(find.text('Использовать'), findsNothing);
      expect(find.text('Её можно применить в свой ход'), findsNothing);
      await endBanners(tester);
    });

    testWidgets('рука соперника, показанная лидером: лист закрывается «Готово»', (tester) async {
      final shown = [cards.unit(Row.melee), cards.unit(Row.ranged), cards.unit(Row.siege)];
      final view = viewOf(cards);
      final harness = await pumpField(tester, view);
      harness.cubit.onMatchState(
        MatchInProgress(view: view, content: content, roster: rosterOf(cards), events: [HandRevealed(Seat.one, shown)]),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Рука противника'), findsOneWidget);
      expect(find.descendant(of: find.byType(CardGridSheet), matching: find.byType(GwentCard)), findsNWidgets(3));
      await tester.tap(find.text('Готово'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CardGridSheet), findsNothing);
      await endBanners(tester);
    });

    testWidgets('кнопка «назад» закрывает лист, а затем снимает выбор', (tester) async {
      final unit = cards.unit(Row.melee);
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      harness.cubit.select(unit.id);
      harness.cubit.openDiscard(mine: true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CardGridSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CardGridSheet), findsNothing);
      expect(harness.cubit.state.selected, isNull);
      await endBanners(tester);
    });

    testWidgets('удержание карты на руке открывает полный просмотр', (tester) async {
      final unit = cards.unit(Row.melee);
      await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit])));
      await tester.longPress(handCards().first);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CardDetailView), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('удержание карты на поле открывает полный просмотр', (tester) async {
      final unit = cards.unit(Row.melee);
      await pumpField(
        tester,
        viewOf(
          cards,
          opponent: sideOf(
            cards,
            Seat.two,
            rows: {
              Row.melee: rowOf([unit], cards),
            },
          ),
        ),
      );
      final fieldCard = find.byWidgetPredicate((widget) => widget is GwentCard && widget.size.name == 'row');
      await tester.longPress(fieldCard.first);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CardDetailView), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('пас', () {
    final haptics = <String>[];

    setUp(() {
      haptics.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('по умолчанию пас нужно держать секунду', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      await tester.tap(find.byType(PassButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.intents, isEmpty, reason: 'короткое нажатие не пасует');
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PassButton)));
      // Заливка стартует на кадре после onTapDown (через 100 мс после касания).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1100));
      await gesture.up();
      await tester.pump();
      expect(harness.intents, [const Pass()]);
      await endBanners(tester);
    });

    testWidgets('с подтверждением тап открывает диалог, подтверждение пасует', (tester) async {
      final harness = await pumpField(
        tester,
        viewOf(cards, me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee), cards.unit(Row.ranged)])),
        confirmPass: true,
      );
      await tester.tap(find.byType(PassButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Спасовать?'), findsOneWidget);
      expect(harness.intents, isEmpty);
      await tester.tap(find.text('Отмена'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.intents, isEmpty);

      await tester.tap(find.byType(PassButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Пас'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.intents, [const Pass()]);
      await endBanners(tester);
    });

    testWidgets('кнопка паса недоступна не в свой ход', (tester) async {
      final harness = await pumpField(tester, viewOf(cards, turn: Seat.two));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PassButton)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1100));
      await gesture.up();
      expect(harness.intents, isEmpty);
      expect(tester.widget<PassButton>(find.byType(PassButton)).enabled, isFalse);
    });

    testWidgets('зона нажатия компактного «Паса» не меньше 44 pt', (tester) async {
      await pumpField(tester, viewOf(cards));
      final size = tester.getSize(find.byType(PassButton));
      expect(size.height, greaterThanOrEqualTo(44));
      await endBanners(tester);
    });
  });

  group('баннеры', () {
    testWidgets('начало раунда: «Раунд 1», затем «Ваш ход», потом баннеры исчезают', (tester) async {
      final view = viewOf(cards);
      final harness = await pumpField(tester, view);
      feed(harness, view, const [RoundStarted(1, Seat.one), TurnStarted(Seat.one)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Раунд 1');
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Ваш ход');
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MatchBannerStrip), findsNothing);
      expect(harness.cubit.state.banners, isEmpty);
    });

    testWidgets('в ход соперника: «Ход противника»', (tester) async {
      final view = viewOf(cards, turn: Seat.two);
      final harness = await pumpField(tester, view);
      feed(harness, view, const [TurnStarted(Seat.two)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Ход противника');
      await endBanners(tester);
    });

    testWidgets('в hot-seat баннер называет игрока по номеру', (tester) async {
      final view = viewOf(cards, turn: Seat.two);
      final harness = await pumpField(tester, view, hotSeat: true);
      feed(harness, view, const [TurnStarted(Seat.two)], hotSeat: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Ход: Игрок 2');
      await endBanners(tester);
    });

    testWidgets("первый ход после выбора Скоя'таэлей: подпись под заголовком, полоса 76 pt, баннер держится дольше", (
      tester,
    ) async {
      final view = viewOf(cards, me: sideOf(cards, Seat.one, faction: Faction.scoiatael));
      final harness = await pumpField(tester, view);
      feed(harness, view, const [FirstPlayerChosen(Seat.one, byChoice: true)]);
      feed(harness, view, const [RoundStarted(1, Seat.one), TurnStarted(Seat.one)]);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Ваш ход');
      expect(find.text("Скоя'таэли: вы выбрали, кто ходит первым"), findsOneWidget);
      expect(tester.getSize(find.byType(MatchBannerStrip)).height, 76);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(MatchBannerStrip), findsOneWidget, reason: 'подпись надо успеть прочесть: баннер идёт 1,8 с');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MatchBannerStrip), findsNothing);
    });

    testWidgets("первый ход после выбора соперника-Скоя'таэля", (tester) async {
      final view = viewOf(
        cards,
        turn: Seat.two,
        opponent: sideOf(cards, Seat.two, faction: Faction.scoiatael),
      );
      final harness = await pumpField(tester, view);
      feed(harness, view, const [FirstPlayerChosen(Seat.two, byChoice: true)]);
      feed(harness, view, const [TurnStarted(Seat.two)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Ход противника');
      expect(find.text("Скоя'таэли: соперник выбрал, кто ходит первым"), findsOneWidget);
      await endBanners(tester);
    });

    testWidgets('в hot-seat подпись называет игрока по номеру', (tester) async {
      final view = viewOf(cards, me: sideOf(cards, Seat.one, faction: Faction.scoiatael));
      final harness = await pumpField(tester, view, hotSeat: true);
      feed(harness, view, const [FirstPlayerChosen(Seat.one, byChoice: true)], hotSeat: true);
      feed(harness, view, const [TurnStarted(Seat.one)], hotSeat: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Скоя'таэли: Игрок 1 выбрал, кто ходит первым"), findsOneWidget);
      await endBanners(tester);
    });

    testWidgets('решающий раунд: у каждого по одному камню', (tester) async {
      final view = viewOf(
        cards,
        round: 3,
        me: sideOf(cards, Seat.one, crystals: 1),
        opponent: sideOf(cards, Seat.two, crystals: 1),
      );
      final harness = await pumpField(tester, view);
      feed(harness, view, const [RoundStarted(3, Seat.one)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Решающий раунд');
      expect(find.text('У каждого по одному камню'), findsOneWidget);
      await endBanners(tester);
    });

    testWidgets('пас соперника: баннер с подсказкой, потом он убирается', (tester) async {
      final view = viewOf(cards, turn: Seat.two);
      final harness = await pumpField(tester, view);
      feed(harness, view, const [Passed(Seat.two, auto: false)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Противник спасовал'), findsOneWidget);
      expect(find.text('Разыграйте карту или спасуйте'), findsOneWidget);
      await endBanners(tester);
      expect(find.text('Противник спасовал'), findsNothing);
      expect(harness.cubit.state.banners, isEmpty);
    });

    testWidgets('свой пас: «Вы спасовали» и ожидание хода противника', (tester) async {
      final view = viewOf(cards, turn: Seat.two, me: sideOf(cards, Seat.one, passed: true));
      final harness = await pumpField(tester, view);
      feed(harness, view, const [Passed(Seat.one, auto: false)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Вы спасовали');
      expect(find.text('Ожидание хода противника'), findsOneWidget);
      await endBanners(tester);
    });

    testWidgets('в hot-seat пас называет игрока', (tester) async {
      final view = viewOf(cards, turn: Seat.two);
      final harness = await pumpField(tester, view, hotSeat: true);
      feed(harness, view, const [Passed(Seat.two, auto: false)], hotSeat: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Игрок 2 спасовал');
      await endBanners(tester);
    });

    testWidgets('при «уменьшить движение» баннер просто появляется и исчезает', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final view = viewOf(cards);
      final harness = await pumpField(tester, view);
      feed(harness, view, const [TurnStarted(Seat.one)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bannerTitle(tester), 'Ваш ход');
      await endBanners(tester);
      expect(find.byType(MatchBannerStrip), findsNothing);
    });

    testWidgets('пока идёт баннер, ход начать нельзя: карта не выбирается, а после баннера выбирается', (tester) async {
      final unit = cards.unit(Row.melee);
      final view = viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit]));
      final harness = await pumpField(tester, view);
      feed(harness, view, const [RoundStarted(1, Seat.one)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.cubit.state.isBusy, isTrue);
      await tester.tap(handCards().first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.selected, isNull);
      await endBanners(tester);
      expect(harness.cubit.state.isBusy, isFalse);
      await tester.tap(handCards().first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.selected, unit.id);
    });
  });

  group('итог раунда', () {
    const won = RoundResult(round: 1, scores: {Seat.one: 17, Seat.two: 9}, winner: Seat.one);

    testWidgets('показывает итог, нажатие в любом месте его закрывает', (tester) async {
      final view = viewOf(cards, round: 2, opponent: sideOf(cards, Seat.two, crystals: 1));
      final harness = await pumpField(tester, view);
      feed(harness, view, [const RoundEnded(won), const RoundStarted(2, Seat.two), const TurnStarted(Seat.two)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RoundSummaryView), findsOneWidget);
      expect(find.text('РАУНД 1 · ИТОГ'), findsOneWidget);
      expect(find.text('Вы выиграли раунд'), findsOneWidget);
      expect(find.text('17'), findsWidgets);
      expect(find.text('Нажмите, чтобы продолжить'), findsOneWidget);
      expect(find.byType(MatchBannerStrip), findsNothing, reason: 'баннеры ждут, пока итог не закроют');

      await tester.tapAt(const Offset(195, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RoundSummaryView), findsNothing);
      expect(bannerTitle(tester), 'Раунд 2');
      await endBanners(tester);
    });

    testWidgets('в hot-seat итог называет победителя по номеру', (tester) async {
      final view = viewOf(cards, round: 2);
      final harness = await pumpField(tester, view, hotSeat: true);
      feed(harness, view, [const RoundEnded(won)], hotSeat: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Игрок 1 выиграл раунд'), findsOneWidget);
    });

    testWidgets('кнопка «назад» закрывает итог, а не открывает паузу', (tester) async {
      final view = viewOf(cards);
      final harness = await pumpField(tester, view);
      feed(harness, view, [const RoundEnded(won)]);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RoundSummaryView), findsNothing);
      expect(harness.cubit.state.pause, PauseLayer.none);
    });
  });

  group('пауза и сдача', () {
    testWidgets('кнопка паузы открывает меню, «Продолжить» и нажатие мимо панели возвращают в игру', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      await tester.tap(find.bySemanticsLabel('Пауза'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(PauseMenuLayer), findsOneWidget);
      expect(find.text('Продолжить'), findsOneWidget);
      expect(find.text('Правила'), findsOneWidget);
      expect(find.text('Сдаться'), findsOneWidget);

      await tester.tap(find.text('Продолжить'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(PauseMenuLayer), findsNothing);

      harness.cubit.openPause();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.pause, PauseLayer.none);
    });

    testWidgets('кнопка паузы имеет зону нажатия не меньше 44 pt', (tester) async {
      await pumpField(tester, viewOf(cards));
      final size = tester.getSize(find.bySemanticsLabel('Пауза'));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('«Настройки» в паузе недоступны', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      harness.cubit.openPause();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<PauseMenuLayer>(find.byType(PauseMenuLayer)).onSettings, isNull);
    });

    testWidgets('«Настройки» в паузе открывают настройки, партия остаётся на паузе', (tester) async {
      var opened = 0;
      final harness = await pumpField(tester, viewOf(cards), onSettings: () => opened++);
      harness.cubit.openPause();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<PauseMenuLayer>(find.byType(PauseMenuLayer)).onSettings, isNotNull);

      await tester.tap(find.text('Настройки'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(opened, 1);
      expect(harness.cubit.state.pause, PauseLayer.menu);
      expect(find.byType(PauseMenuLayer), findsOneWidget);
    });

    testWidgets('«Правила» открывают справочник, «назад» возвращает в меню паузы', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      harness.cubit.openPause();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Правила'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(RulesView), findsOneWidget);
      expect(find.text('Цель'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(RulesView), findsNothing);
      expect(harness.cubit.state.pause, PauseLayer.menu);
    });

    testWidgets('«Сдаться» спрашивает подтверждение; «Отмена» возвращает в меню, ход не отправляется', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      harness.cubit.openPause();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Сдаться'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SurrenderConfirmLayer), findsOneWidget);
      expect(find.text('Матч будет засчитан как поражение.'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SurrenderConfirmLayer), findsNothing);
      expect(find.byType(PauseMenuLayer), findsOneWidget);
      expect(harness.intents, isEmpty);
    });

    testWidgets('подтверждённая сдача отправляет Resign и закрывает слой', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      harness.cubit
        ..openPause()
        ..askSurrender();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.descendant(of: find.byType(SurrenderConfirmLayer), matching: find.text('Сдаться')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.intents, [const Resign()]);
      expect(harness.cubit.state.pause, PauseLayer.none);
    });

    testWidgets('кнопка «назад» на чистом поле открывает паузу, повторное нажатие закрывает', (tester) async {
      final harness = await pumpField(tester, viewOf(cards));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.pause, PauseLayer.menu);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 250));
      expect(harness.cubit.state.pause, PauseLayer.none);
    });

    testWidgets('баннер не показывается под паузой', (tester) async {
      final view = viewOf(cards);
      final harness = await pumpField(tester, view);
      harness.cubit.openPause();
      feed(harness, view, const [TurnStarted(Seat.one)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MatchBannerStrip), findsNothing);
    });
  });

  group('отображение', () {
    testWidgets('погода в слотах центральной полосы и сила ряда с цветом изменения', (tester) async {
      final unit = cards.unit(Row.melee);
      final base = cards.strength(unit);
      await pumpField(
        tester,
        viewOf(
          cards,
          me: sideOf(
            cards,
            Seat.one,
            rows: {
              Row.melee: rowOf([unit], cards, weather: true, strength: 1),
              Row.ranged: rowOf([cards.unit(Row.ranged)], cards, strength: 99),
            },
          ),
          opponent: sideOf(cards, Seat.two, rows: {Row.melee: rowOf([], cards, weather: true)}),
        ),
      );
      final slots = tester.widget<WeatherStrip>(find.byType(WeatherStrip)).slots;
      expect(slots.map((slot) => slot.weather), [GwentWeather.frost, null, null]);
      final tones = [for (final pill in tester.widgetList<RowScorePill>(find.byType(RowScorePill))) pill.tone.name];
      expect(
        tones.where((tone) => tone == 'weakened'),
        hasLength(greaterThanOrEqualTo(1)),
        reason: 'база $base, сила 1',
      );
      expect(tones, contains('boosted'));
      await endBanners(tester);
    });

    testWidgets('пилюля силы ряда по цифре, а не на всю колонку', (tester) async {
      await pumpField(tester, viewOf(cards));
      final size = tester.getSize(find.byType(RowScorePill).first);
      expect(size.width, RowScorePill.minWidth);
      expect(size.height, RowScorePill.height);
      await endBanners(tester);
    });

    testWidgets('десять карт в руке веером: крайние карты целиком в пределах экрана', (tester) async {
      final hand = [
        for (var i = 0; i < 10; i++) cards.unit(Row.values[i % 3]),
      ];
      await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: hand)));
      expect(find.descendant(of: find.byType(HandView), matching: find.byType(ListView)), findsNothing);
      var left = double.infinity;
      var right = double.negativeInfinity;
      for (final element in handCards().evaluate()) {
        final box = element.renderObject! as RenderBox;
        for (final corner in [
          Offset.zero,
          Offset(box.size.width, 0),
          Offset(0, box.size.height),
          box.size.bottomRight(Offset.zero),
        ]) {
          final point = box.localToGlobal(corner);
          left = left < point.dx ? left : point.dx;
          right = right > point.dx ? right : point.dx;
        }
      }
      expect(left, greaterThanOrEqualTo(4));
      expect(right, lessThanOrEqualTo(390 - 4));
      await endBanners(tester);
    });

    testWidgets('двенадцать карт: прокрутка вместо веера, выбранная с края карта доезжает до центра', (tester) async {
      final hand = [for (var i = 0; i < 12; i++) cards.unit(Row.values[i % 3])];
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: hand)));
      expect(find.descendant(of: find.byType(HandView), matching: find.byType(ListView)), findsOneWidget);
      // Пятая карта торчит из-за правого края экрана: тап по видимой части выбирает её.
      await tester.tapAt(Offset(375, geometry.handTop + 80));
      await tester.pumpAndSettle();
      expect(harness.cubit.state.selected, hand[4].id);
      // Список ленивый: после прокрутки номера карт в дереве сдвигаются, поэтому выбранную ищем по подсветке.
      final selected = find.descendant(
        of: find.byType(HandView),
        matching: find.byWidgetPredicate((widget) => widget is GwentCard && widget.highlight == CardHighlight.selected),
      );
      final box = tester.renderObject<RenderBox>(selected);
      expect(box.localToGlobal(box.size.center(Offset.zero)).dx, closeTo(195, 40));
      await endBanners(tester);
    });

    testWidgets('рука в одну линию прокручивается жестом по самим картам, а не только по фону между ними', (
      tester,
    ) async {
      final hand = [for (var i = 0; i < 12; i++) cards.unit(Row.values[i % 3])];
      await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: hand)));
      await endBanners(tester);
      final scrollable = find.descendant(of: find.byType(HandView), matching: find.byType(Scrollable));
      double offset() => tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset(), 0);

      await tester.drag(handCards().at(2), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(offset(), greaterThan(60), reason: 'горизонтальный сдвиг за карту должен листать руку');
    });

    testWidgets('рука в одну линию: сдвиг вверх по карте по-прежнему тянет её на цель, а не листает', (tester) async {
      final unit = cards.unit(Row.melee);
      final hand = [unit, for (var i = 0; i < 11; i++) cards.unit(Row.values[i % 3])];
      final harness = await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: hand)));
      await endBanners(tester);
      final scrollable = find.descendant(of: find.byType(HandView), matching: find.byType(Scrollable));

      final gesture = await tester.startGesture(tester.getCenter(handCards().first));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      expect(harness.cubit.state.selected, unit.id, reason: 'вертикальный сдвиг начинает перетаскивание');
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('низкий экран: поле уменьшается целиком без переполнения', (tester) async {
      await pumpField(tester, viewOf(cards), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      const scale = 568 / FieldGeometry.budgetHeight;
      expect(tester.getRect(find.byType(WeatherStrip)).height, closeTo(40 * scale, 0.5));
      expect(tester.getRect(find.byType(FieldView)).height, 568);
      await endBanners(tester);
    });

    testWidgets('высокий экран: ряды остаются по 80 pt, лишнее достаётся руке', (tester) async {
      await pumpField(tester, viewOf(cards), size: const Size(390, 1000));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(WeatherStrip)).top, 288);
      await endBanners(tester);
    });
  });
}
