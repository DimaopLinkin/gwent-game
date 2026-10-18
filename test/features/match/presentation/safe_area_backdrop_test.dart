import 'package:flutter/material.dart' hide Intent, Row;
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/theme/app_theme.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/content/domain/game_content.dart';
import 'package:gwent/src/features/match/presentation/field/field_cubit.dart';
import 'package:gwent/src/features/match/presentation/field/field_view.dart';
import 'package:gwent/src/features/match/presentation/match_screen_state.dart';
import 'package:gwent/src/features/match/presentation/overlays/match_result_view.dart';
import 'package:gwent/src/features/match/presentation/start/handover_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_intro_view.dart';
import 'package:gwent/src/features/match/presentation/start/match_toss_view.dart';
import 'package:gwent/src/features/match/presentation/start/redraw_view.dart';
import 'package:gwent_engine/gwent_engine.dart';

import '../../../support/fonts.dart';
import '../../../support/match_fixtures.dart';
import 'field/field_fixtures.dart';

/// Вырез сверху и жест «домой» снизу, как у iPhone.
const _top = 59.0;
const _bottom = 34.0;
const _screen = Size(390, 844);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameContent content;
  late TestCards cards;

  setUpAll(() async {
    content = await loadBaseContent();
    await loadDesignFonts();
  });
  setUp(() => cards = TestCards(content));

  /// Рисует [screen] на экране с вырезом и возвращает цвет пикселя в точке [at].
  Future<List<Color>> colorsAt(WidgetTester tester, Widget screen, List<Offset> points, {FieldCubit? cubit}) async {
    tester.view
      ..physicalSize = _screen
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: _top, bottom: _bottom)
      ..viewPadding = const FakeViewPadding(top: _top, bottom: _bottom);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            // Цвет, которого нет ни на одном экране игры: если фон не дошёл до края, он проступит.
            backgroundColor: const Color(0xFFFF00FF),
            body: cubit == null ? screen : BlocProvider.value(value: cubit, child: screen),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    final image = (await tester.runAsync(() => tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage()))!;
    final bytes = (await tester.runAsync(image.toByteData))!;
    return [
      for (final point in points)
        Color.fromARGB(
          255,
          bytes.getUint8(((point.dy.toInt() * image.width) + point.dx.toInt()) * 4),
          bytes.getUint8(((point.dy.toInt() * image.width) + point.dx.toInt()) * 4 + 1),
          bytes.getUint8(((point.dy.toInt() * image.width) + point.dx.toInt()) * 4 + 2),
        ),
    ];
  }

  // Две точки у левого края (там нет содержимого): в зоне выреза и сразу за её границей, внутри безопасной области.
  const aboveTop = Offset(2, _top / 2);
  const belowTop = Offset(2, _top + 6);
  final aboveBottom = Offset(2, _screen.height - _bottom / 2);
  final belowBottom = Offset(2, _screen.height - _bottom - 6);

  void expectSeamless(List<Color> colors, String screen, {int tolerance = 14}) {
    int channel(double value) => (value * 255).round();
    int diff(Color a, Color b) => [
      (channel(a.r) - channel(b.r)).abs(),
      (channel(a.g) - channel(b.g)).abs(),
      (channel(a.b) - channel(b.b)).abs(),
    ].reduce((a, b) => a > b ? a : b);
    const magenta = Color(0xFFFF00FF);
    for (final color in colors) {
      expect(diff(color, magenta), greaterThan(40), reason: '$screen: фон не дошёл до края экрана');
    }
    expect(diff(colors[0], colors[1]), lessThanOrEqualTo(tolerance), reason: '$screen: шов у выреза');
    expect(diff(colors[2], colors[3]), lessThanOrEqualTo(tolerance), reason: '$screen: шов у жеста «домой»');
  }

  final points = [aboveTop, belowTop, aboveBottom, belowBottom];

  group('фон идёт на весь экран, содержимое в безопасной области', () {
    testWidgets('поле', (tester) async {
      final view = viewOf(cards, me: sideOf(cards, Seat.one, hand: [cards.unit(Row.melee)]));
      final cubit = FieldCubit();
      addTearDown(cubit.close);
      final colors = await colorsAt(
        tester,
        FieldView(view: view, content: content, roster: rosterOf(cards), onIntent: (_) {}),
        points,
        cubit: cubit,
      );
      expectSeamless(colors, 'поле', tolerance: 2);
    });

    testWidgets('знакомство, жребий, выбор первого игрока и передача телефона', (tester) async {
      final roster = rosterOf(cards, hotSeat: true);
      final screens = <String, Widget>{
        'знакомство': MatchIntroView(roster: roster, onFinished: () {}),
        'жребий': MatchTossView(roster: roster, first: Seat.one, byChoice: false, onFinished: () {}),
        'передача телефона': MatchHandoverView(
          next: Seat.two,
          kind: HandoverKind.turn,
          roster: roster,
          onReady: () {},
        ),
      };
      for (final MapEntry(:key, :value) in screens.entries) {
        expectSeamless(await colorsAt(tester, value, points), key);
      }
    });

    testWidgets('пересдача и итог матча', (tester) async {
      final roster = rosterOf(cards);
      final hand = [for (var i = 0; i < 6; i++) cards.unit(Row.values[i % 3])];
      final redraw = viewOf(
        cards,
        phase: MatchPhase.redraw,
        me: sideOf(cards, Seat.one, hand: hand, redrawsLeft: 2),
      );
      expectSeamless(
        await colorsAt(tester, MatchRedrawView(view: redraw, roster: roster, onIntent: (_) {}), points),
        'пересдача',
      );
      final finished = viewOf(
        cards,
        phase: MatchPhase.finished,
        turn: null,
        outcome: const MatchOutcome(winner: Seat.one, reason: MatchEndReason.crystals),
      );
      expectSeamless(
        await colorsAt(
          tester,
          MatchResultView(view: finished, roster: roster, onExit: () {}, onRematch: () {}),
          points,
        ),
        'итог матча',
      );
    });
  });
}
