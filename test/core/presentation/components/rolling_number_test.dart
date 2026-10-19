import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/components/rolling_number.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';

void main() {
  const style = TextStyle(fontSize: 14, color: Color(0xFFFFFFFF), height: 1);

  Future<void> pumpNumber(WidgetTester tester, RollValue value) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: RollingNumber(value, style: style)),
    ),
  );

  testWidgets('закончившаяся прокрутка показывает одно новое число', (tester) async {
    await pumpNumber(tester, const RollValue(4, 9));
    expect(find.text('9'), findsOneWidget);
    expect(find.text('4'), findsNothing);
  });

  testWidgets('посреди прокрутки видны и старое, и новое число', (tester) async {
    await pumpNumber(tester, const RollValue(4, 9, progress: 0.5));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('прирост подсвечивается зелёным, потеря красным', (tester) async {
    await pumpNumber(tester, const RollValue(4, 9, flash: 1, tone: RollTone.gain));
    expect(tester.widget<Text>(find.text('9')).style?.color, GwentColors.buff);
    await pumpNumber(tester, const RollValue(9, 4, flash: 1, tone: RollTone.loss));
    expect(tester.widget<Text>(find.text('4')).style?.color, GwentColors.debuff);
  });

  test('settled: прокрутка закончена и подсветки нет', () {
    expect(const RollValue(1, 2).settled, isTrue);
    expect(const RollValue(1, 2, progress: 0.4).settled, isFalse);
    expect(const RollValue(1, 2, flash: 0.3).settled, isFalse);
    expect(const RollValue(1, 2, progress: 0.4).nearest, 1);
    expect(const RollValue(1, 2, progress: 0.6).nearest, 2);
  });
}
