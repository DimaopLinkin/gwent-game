import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/core/presentation/card/parts/card_coin.dart';
import 'package:gwent/src/core/presentation/card/parts/compact_power.dart';
import 'package:gwent/src/core/presentation/card/parts/power_medallion.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';

import '../../../support/fonts.dart';
import '../../../support/localized_app.dart';

void main() {
  setUpAll(loadDesignFonts);

  Future<void> pump(WidgetTester tester, CompactPower power) =>
      tester.pumpWidget(localizedApp(Align(alignment: Alignment.topLeft, child: power)));

  bool hasIcon(GwentIcon icon) =>
      find.byWidgetPredicate((widget) => widget is GwentIconView && widget.icon == icon).evaluate().isNotEmpty;

  for (final width in const [12.0, 16.0, 28.0]) {
    testWidgets('ширина ${width.toInt()} pt: число, стрелка и монета способности внутри полоски, ниже 74 pt', (
      tester,
    ) async {
      await pump(
        tester,
        CompactPower(power: 12, look: PowerLook.buffed, width: width, ability: GwentIcon.abilityTightBond),
      );
      expect(tester.takeException(), isNull);
      // Число рисуют два слоя (обводка и заливка), слой обводки скрыт от скринридера.
      expect(find.text('12'), findsNWidgets(2));
      expect(find.descendant(of: find.byType(CompactPower), matching: find.byType(ExcludeSemantics)), findsOneWidget);
      expect(hasIcon(GwentIcon.iconPowerUp), isTrue);
      expect(hasIcon(GwentIcon.abilityTightBond), isTrue);
      final size = tester.getSize(find.byType(CompactPower));
      expect(size.width, width - 1);
      expect(size.height, lessThan(60));
      // Монета вместе с ободком (0,75 pt с каждой стороны) не шире полоски: соседние монеты не налезают.
      final coin = tester.getSize(find.byType(CardCoin));
      expect(coin.width + 1.5, lessThanOrEqualTo(size.width));
    });
  }

  testWidgets('без способности монеты нет, герой и базовая сила без стрелки', (tester) async {
    for (final look in [PowerLook.base, PowerLook.hero]) {
      await pump(tester, CompactPower(power: 7, look: look, width: 16));
      expect(find.byType(CardCoin), findsNothing);
      expect(hasIcon(GwentIcon.iconPowerUp), isFalse);
      expect(hasIcon(GwentIcon.iconPowerDown), isFalse);
    }
  });

  testWidgets('ослабленная карта показывает стрелку вниз', (tester) async {
    await pump(tester, const CompactPower(power: 1, look: PowerLook.debuffed, width: 16));
    expect(hasIcon(GwentIcon.iconPowerDown), isTrue);
  });

  testWidgets('нулевая ширина не падает', (tester) async {
    await pump(tester, const CompactPower(power: 3, look: PowerLook.base, width: 0, ability: GwentIcon.abilitySpy));
    expect(tester.takeException(), isNull);
  });
}
