import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gwent/src/app/theme/app_theme.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_colors.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_faction.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_icon_view.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_space.dart';
import 'package:gwent/src/core/presentation/design_system/gwent_text.dart';

import '../../../support/localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('у каждого слота иконки есть SVG в ассетах, кроме гербов он перекрашивается через currentColor', () async {
    for (final icon in GwentIcon.values) {
      final svg = await rootBundle.loadString(icon.assetPath);
      expect(svg, startsWith('<svg'), reason: icon.assetPath);
      if (!icon.isCrest) expect(svg, contains('currentColor'), reason: icon.assetPath);
    }
  });

  test('у каждой фракции колоды есть герб, у нейтральных — нет', () {
    for (final faction in GwentFaction.values) {
      expect(faction.crest == null, faction == GwentFaction.neutral, reason: '$faction');
      expect(faction.crest?.isCrest ?? true, isTrue);
    }
    expect(GwentFaction.fromKey('skellige'), GwentFaction.skellige);
    expect(GwentFaction.fromKey('unknown'), GwentFaction.neutral);
  });

  test('тема собрана из токенов дизайн-системы', () {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, GwentColors.bg);
    expect(theme.colorScheme.primary, GwentColors.gold);
    expect(theme.textTheme.bodyLarge?.fontFamily, GwentText.alegreya);
    expect(theme.textTheme.titleLarge?.fontFamily, GwentText.cormorant);

    final primary = theme.filledButtonTheme.style!;
    expect(primary.backgroundColor!.resolve({}), GwentColors.gold);
    expect(primary.foregroundColor!.resolve({}), GwentColors.onGold);
    expect(primary.minimumSize!.resolve({})!.height, GwentSpace.buttonHeight);
    expect(primary.backgroundColor!.resolve({WidgetState.disabled}), GwentColors.disabledFill);

    final secondary = theme.outlinedButtonTheme.style!;
    expect(secondary.side!.resolve({})!.color, GwentColors.brass);
  });

  testWidgets('иконка рисуется заданным размером, кнопки темы — не ниже 48', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        Column(
          children: [
            const GwentIconView(GwentIcon.abilitySpy, size: 24),
            FilledButton(onPressed: () {}, child: const Text('Играть')),
            OutlinedButton(onPressed: () {}, child: const Text('Назад')),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(GwentIconView)), const Size.square(24));
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThanOrEqualTo(48));
  });
}
