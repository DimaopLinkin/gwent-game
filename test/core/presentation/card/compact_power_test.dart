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

  for (final look in PowerLook.values) {
    for (final width in const [12.0, 16.0, 28.0]) {
      testWidgets('$look, ширина ${width.toInt()} pt: медальон с кольцами и монета укладываются в полоску', (
        tester,
      ) async {
        await pump(
          tester,
          CompactPower(power: 12, look: look, width: width, abilities: const [GwentIcon.abilityTightBond]),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(PowerMedallion), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(hasIcon(GwentIcon.abilityTightBond), isTrue);
        // Стрелок усиления и ослабления в сжатом виде нет: состояние видно по цвету медальона.
        expect(hasIcon(GwentIcon.iconPowerUp), isFalse);
        expect(hasIcon(GwentIcon.iconPowerDown), isFalse);
        final size = tester.getSize(find.byType(CompactPower));
        expect(size.width, width - 1);
        expect(size.height, lessThan(60));
        // Кольца медальона (2 pt, у героя 3 pt) и ободок монеты (0,75 pt) рисуются тенями вокруг диска.
        final disc = tester.getSize(find.byType(PowerMedallion));
        expect(disc.width + 2 * (look == PowerLook.hero ? 3 : 2), lessThanOrEqualTo(size.width + 0.01));
        final coin = tester.getSize(find.byType(CardCoin));
        expect(coin.width + 1.5, lessThanOrEqualTo(size.width));
      });
    }
  }

  testWidgets('без способностей монет нет, несколько способностей — по монете на каждую', (tester) async {
    await pump(tester, const CompactPower(power: 7, look: PowerLook.base, width: 16));
    expect(find.byType(CardCoin), findsNothing);
    await pump(
      tester,
      const CompactPower(
        power: 7,
        look: PowerLook.base,
        width: 16,
        abilities: [GwentIcon.rowAgile, GwentIcon.abilitySpy],
      ),
    );
    expect(find.byType(CardCoin), findsNWidgets(2));
  });

  testWidgets('нулевая ширина не падает', (tester) async {
    await pump(
      tester,
      const CompactPower(power: 3, look: PowerLook.hero, width: 0, abilities: [GwentIcon.abilitySpy]),
    );
    expect(tester.takeException(), isNull);
  });
}
