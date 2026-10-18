import 'package:flutter/material.dart' hide Intent, Row;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/gwent_card.dart';
import 'package:gwent/src/core/presentation/components/row_score_pill.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_geometry.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/field/hand_view.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_layer.dart';
import 'package:gwent/src/features/match/presentation/stage/stage_tokens.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../../support/fonts.dart';
import '../../../../support/localized_app.dart';
import '../../../../support/match_fixtures.dart';
import 'field_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;
  late FieldCubit cubit;

  setUpAll(() async {
    content = await loadBaseContent();
    await loadDesignFonts();
  });
  setUp(() {
    cards = TestCards(content);
    cubit = FieldCubit();
    addTearDown(cubit.close);
  });

  void feed(PlayerView view, List<GameEvent> events, {StageStyle style = StageStyle.normal}) => cubit.onMatchState(
    MatchInProgress(view: view, content: content, roster: rosterOf(cards), events: events),
    style: style,
  );

  /// Ход: рука [before] → ряд с картой; до хода поле уже видело проекцию без событий.
  ({PlayerView before, PlayerView after, List<GameEvent> events}) playUnit() {
    final unit = cards.unit(Row.melee);
    final other = cards.unit(Row.ranged);
    return (
      before: viewOf(cards, me: sideOf(cards, Seat.one, hand: [unit, other])),
      after: viewOf(
        cards,
        me: sideOf(
          cards,
          Seat.one,
          hand: [other],
          rows: {
            Row.melee: rowOf([unit], cards),
          },
          score: cards.strength(unit),
        ),
      ),
      events: [CardPlayed(Seat.one, unit), UnitPlaced(Seat.one, Row.melee, unit, EntrySource.hand)],
    );
  }

  Future<void> pumpField(WidgetTester tester, PlayerView view) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        BlocProvider.value(
          value: cubit,
          child: BlocBuilder<FieldCubit, Object?>(
            builder: (context, _) => FieldView(view: view, content: content, roster: rosterOf(cards), onIntent: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('держатель поля', () {
    test('первое состояние партии сценария не даёт: сравнивать не с чем', () {
      final play = playUnit();
      feed(play.after, play.events);
      expect(cubit.state.stage, isNull);
    });

    test('ход после увиденного состояния даёт сценарий, и поле занято, пока он не отыгран', () {
      final play = playUnit();
      feed(play.before, const []);
      feed(play.after, play.events);
      expect(cubit.state.stage, isNotNull);
      expect(cubit.state.isBusy, isTrue);
      cubit.endStage(cubit.state.stage!.id);
      expect(cubit.state.stage, isNull);
      expect(cubit.state.isBusy, isFalse);
    });

    test('сценарий чужого номера поле не снимает', () {
      final play = playUnit();
      feed(play.before, const []);
      feed(play.after, play.events);
      cubit.endStage(cubit.state.stage!.id + 1);
      expect(cubit.state.stage, isNotNull);
    });

    test('быстрая скорость даёт более короткий сценарий', () {
      final play = playUnit();
      feed(play.before, const []);
      feed(play.after, play.events);
      final normal = cubit.state.stage!.duration;
      final fast = FieldCubit();
      addTearDown(fast.close);
      fast
        ..onMatchState(
          MatchInProgress(view: play.before, content: content, roster: rosterOf(cards), events: const []),
        )
        ..onMatchState(
          MatchInProgress(view: play.after, content: content, roster: rosterOf(cards), events: play.events),
          style: const StageStyle(scale: StageTokens.fastFactor),
        );
      expect(fast.state.stage!.duration, lessThan(normal));
    });

    test('новая партия забывает прежнюю проекцию', () {
      final play = playUnit();
      feed(play.before, const []);
      cubit.onMatchState(const MatchStarting());
      feed(play.after, play.events);
      expect(cubit.state.stage, isNull);
    });
  });

  group('поле', () {
    testWidgets('геометрия руки совпадает с рукой на экране (средняя карта веера не повёрнута)', (tester) async {
      final hand = [cards.unit(Row.melee), cards.unit(Row.ranged), cards.unit(Row.melee)];
      await pumpField(tester, viewOf(cards, me: sideOf(cards, Seat.one, hand: hand)));
      const geometry = FieldGeometry(width: 390, handHeight: 844 - 616);
      final shown = tester.getRect(
        find.descendant(of: find.byType(HandView), matching: find.byType(GwentCard)).at(1),
      );
      final expected = geometry.handCardRect(1, 3);
      expect(shown.left, closeTo(expected.left, 1));
      expect(shown.top, closeTo(expected.top, 1));
      expect(shown.size, expected.size);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('сценарий идёт на поле: слой эффектов виден, рука под вуалью, в конце всё свободно', (tester) async {
      final play = playUnit();
      feed(play.before, const []);
      await pumpField(tester, play.before);
      feed(play.after, play.events);
      await tester.pumpWidget(
        localizedApp(
          BlocProvider.value(
            value: cubit,
            child: BlocBuilder<FieldCubit, Object?>(
              builder: (context, _) =>
                  FieldView(view: play.after, content: content, roster: rosterOf(cards), onIntent: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(StageLayer), findsOneWidget);
      expect(find.byType(HandView), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(StageLayer), findsOneWidget);
      expect(find.byType(RowScorePill), findsWidgets);

      await tester.pump(const Duration(seconds: 3));
      expect(cubit.state.stage, isNull);
      expect(find.byType(StageLayer), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('тап по полю ускоряет показ', (tester) async {
      final play = playUnit();
      feed(play.before, const []);
      await pumpField(tester, play.before);
      feed(play.after, play.events);
      await tester.pumpWidget(
        localizedApp(
          BlocProvider.value(
            value: cubit,
            child: BlocBuilder<FieldCubit, Object?>(
              builder: (context, _) =>
                  FieldView(view: play.after, content: content, roster: rosterOf(cards), onIntent: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final duration = cubit.state.stage!.duration;
      await tester.tapAt(const Offset(195, 300));
      await tester.pump(Duration(milliseconds: (duration / StageTokens.tapSpeedUp).ceil() + 100));
      await tester.pump(const Duration(milliseconds: 50));
      expect(cubit.state.stage, isNull, reason: 'тап ускорил показ в ${StageTokens.tapSpeedUp} раз');
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
