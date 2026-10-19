import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/l10n/l10n.dart';
import 'package:gwent/src/features/match/presentation/setup/bot_difficulty_text.dart';
import 'package:gwent/src/features/match/presentation/setup/difficulty_select_view.dart';
import 'package:gwent_ai/gwent_ai.dart' show BotDifficulty;

import '../../../support/localized_app.dart';
import '../../../support/screen_guards.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async => l10n = await AppLocalizations.delegate.load(const Locale('ru')));

  Future<void> pump(
    WidgetTester tester, {
    BotDifficulty selected = BotDifficulty.normal,
    ValueChanged<BotDifficulty>? onSelect,
    VoidCallback? onConfirm,
    VoidCallback? onBack,
    bool busy = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedScreen(
        DifficultySelectView(
          eyebrow: l10n.setupStep(1, 3),
          selected: selected,
          onSelect: onSelect ?? (_) {},
          onConfirm: onConfirm ?? () {},
          onBack: onBack ?? () {},
          busy: busy,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('четыре уровня с названиями и описаниями, шапка по правилам экранов', (tester) async {
    await pump(tester);

    expect(find.text(l10n.difficultySelectTitle), findsOneWidget);
    for (final difficulty in BotDifficulty.values) {
      expect(find.text(botDifficultyName(l10n, difficulty)), findsOneWidget);
      expect(find.text(botDifficultyDescription(l10n, difficulty)), findsOneWidget);
    }
    expect(find.text('НА СМЕРТЬ!'), findsOneWidget);
    expectNoFallbackTextStyle(tester);
    expectBackButtonAtEdge(tester);
  });

  testWidgets('нажатие выбирает уровень, кнопка подтверждает, «Назад» возвращает', (tester) async {
    final chosen = <BotDifficulty>[];
    var confirmed = 0;
    var backs = 0;
    await pump(tester, onSelect: chosen.add, onConfirm: () => confirmed++, onBack: () => backs++);

    await tester.tap(find.text(botDifficultyName(l10n, BotDifficulty.hard)));
    await tester.tap(find.text(l10n.difficultySelectConfirm));
    await tester.tap(find.bySemanticsLabel(l10n.setupBack));

    expect(chosen, [BotDifficulty.hard]);
    expect(confirmed, 1);
    expect(backs, 1);
  });

  testWidgets('пока идёт сохранение, кнопка не принимает нажатий', (tester) async {
    var confirmed = 0;
    await pump(tester, onConfirm: () => confirmed++, busy: true);

    await tester.tap(find.text(l10n.difficultySelectConfirm));

    expect(confirmed, 0);
  });

  testWidgets('выбранный уровень отмечен для дикторов', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, selected: BotDifficulty.easy);

    expect(
      tester.getSemantics(find.bySemanticsLabel(botDifficultyName(l10n, BotDifficulty.easy))),
      matchesSemantics(
        label: botDifficultyName(l10n, BotDifficulty.easy),
        value: botDifficultyDescription(l10n, BotDifficulty.easy),
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
