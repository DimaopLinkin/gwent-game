import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/life_gems.dart';
import 'package:gwent/src/core/presentation/components/score_badge.dart';

import '../../../support/localized_app.dart';

void main() {
  testWidgets('камни-жизни: целые и потерянные, подпись для скринридера', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(localizedApp(const LifeGems(remaining: 1)));
    final gems = tester.widgetList<LifeGem>(find.byType(LifeGem)).toList();
    expect(gems.map((gem) => gem.lost), [false, true]);
    expect(find.bySemanticsLabel('Кристаллов: 1 из 2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('бейдж силы ряда: размер 32, трёхзначное число мельче, ноль приглушён', (tester) async {
    Future<TextStyle> styleOf(int score) async {
      await tester.pumpWidget(localizedApp(Center(child: RowScoreBadge(score: score))));
      expect(tester.getSize(find.byType(RowScoreBadge)), const Size.square(RowScoreBadge.diameter));
      return tester.widget<Text>(find.text('$score')).style!;
    }

    expect((await styleOf(14)).fontSize, 16);
    expect((await styleOf(112)).fontSize, 14);
    final empty = await styleOf(0);
    final normal = await styleOf(14);
    expect(empty.color, isNot(normal.color));
  });

  testWidgets('общий счёт: 52 pt, у ведущего корона', (tester) async {
    await tester.pumpWidget(localizedApp(const Center(child: TotalScoreBadge(score: 30))));
    expect(tester.getSize(find.byType(TotalScoreBadge)), const Size.square(52));
    final plain = find.descendant(of: find.byType(TotalScoreBadge), matching: find.byType(Positioned));
    final withoutCrown = plain.evaluate().length;

    await tester.pumpWidget(localizedApp(const Center(child: TotalScoreBadge(score: 112, leading: true))));
    expect(
      find.descendant(of: find.byType(TotalScoreBadge), matching: find.byType(Positioned)).evaluate().length,
      withoutCrown + 1,
    );
    expect(find.text('112'), findsOneWidget);
  });
}
